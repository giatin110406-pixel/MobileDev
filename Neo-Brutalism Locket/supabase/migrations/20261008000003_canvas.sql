-- Shared pixel canvas, one active per group (r/place style).
-- The canvas lives in one row (width*height bytes, one palette index per byte), so a
-- 32x32 canvas is 1 KB. Every change is also an append-only canvas_events row:
-- realtime, catching up after a dropped connection, timelapse and rollback all
-- read that log.
--
-- Two people painting the same cell: the canvas row is locked while painting, so
-- the server orders them; the later one wins. Both really painted, both pay 1 Ink.

create table public.palettes (
  id text primary key,
  name text not null,
  -- Index 0 is the empty canvas colour.
  colors text[] not null check (array_length(colors, 1) = 16)
);

insert into public.palettes (id, name, colors) values
  ('eightbit', '8-bit', array[
    '#0F0F1B', '#565A75', '#C6B7BE', '#FAFBF6',
    '#D95763', '#8F3F4A', '#EE8D3D', '#FBD54C',
    '#A8D95A', '#3E9B5E', '#4FCDE0', '#3A66D8',
    '#2C2C7E', '#8A5BD6', '#E76CB5', '#7A4B2A']),
  ('vangogh', 'Van Gogh', array[
    '#F3E9D2', '#1D2B53', '#2F4B8F', '#4D7FC4',
    '#8DB7D8', '#F2C94C', '#E8A317', '#C97B1E',
    '#7A9E4A', '#3F6B3A', '#26402B', '#B4573A',
    '#7B3B2A', '#D9C7A0', '#5E5240', '#171717']);

create table public.canvases (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  width int not null check (width in (16, 24, 32)),
  height int not null check (height = width),
  palette_id text not null references public.palettes (id),
  pixels bytea not null,
  version bigint not null default 0,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  check (octet_length(pixels) = width * height)
);
create unique index canvases_one_active_per_group
  on public.canvases (group_id) where status = 'active';

create table public.canvas_events (
  id bigint generated always as identity primary key,
  canvas_id uuid not null references public.canvases (id) on delete cascade,
  x int not null,
  y int not null,
  color int not null,
  prev_color int not null,
  -- Null after the painter deletes their account; the pixel stays.
  user_id uuid references public.profiles (id) on delete set null,
  batch_id uuid not null,
  version bigint not null,
  created_at timestamptz not null default now(),
  unique (canvas_id, version)
);
create index canvas_events_user_idx
  on public.canvas_events (canvas_id, user_id, created_at desc);

create function public.is_canvas_member(p_canvas uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.canvases c
    where c.id = p_canvas and public.is_group_member(c.group_id)
  )
$$;
revoke all on function public.is_canvas_member(uuid) from public, anon;
grant execute on function public.is_canvas_member(uuid) to authenticated;

alter table public.palettes enable row level security;
alter table public.canvases enable row level security;
alter table public.canvas_events enable row level security;

create policy "everyone reads palettes"
  on public.palettes for select to authenticated using (true);
create policy "members read canvases"
  on public.canvases for select to authenticated
  using (public.is_group_member(group_id));
create policy "members read canvas events"
  on public.canvas_events for select to authenticated
  using (public.is_canvas_member(canvas_id));

grant select on public.palettes, public.canvases, public.canvas_events
  to authenticated;

-- Every new group gets an empty 32x32 canvas.
create function public.new_group_canvas() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.canvases (group_id, width, height, palette_id, pixels)
  values (new.id, 32, 32, 'eightbit', decode(repeat('00', 32 * 32), 'hex'));
  return new;
end;
$$;
revoke all on function public.new_group_canvas() from public, anon, authenticated;
create trigger groups_new_canvas after insert on public.groups
  for each row execute function public.new_group_canvas();

-- RPCs -------------------------------------------------------------------------------------
-- Errors (message): not_signed_in, not_found, not_member, not_owner, canvas_locked,
-- bad_pixel, too_many_pixels, insufficient_ink, rate_limited, bad_size, bad_palette.

-- The whole canvas: the app draws from this and then follows canvas_events.
create function public.get_canvas(p_canvas uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c public.canvases;
  pal public.palettes;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select * into c from public.canvases where id = p_canvas;
  if c.id is null or not public.is_group_member(c.group_id) then
    raise exception 'not_found';
  end if;
  select * into pal from public.palettes where id = c.palette_id;
  return jsonb_build_object(
    'id', c.id,
    'group_id', c.group_id,
    'width', c.width,
    'height', c.height,
    'palette', to_jsonb(pal.colors),
    'pixels', encode(c.pixels, 'base64'),
    'version', c.version,
    'status', c.status,
    'ink_balance', (public.touch_wallet(auth.uid())).balance
  );
end;
$$;

-- The active canvas of a group (so the app does not need its id first).
create function public.get_group_canvas(p_group uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if not public.is_group_member(p_group) then raise exception 'not_found'; end if;
  select id into cid from public.canvases
  where group_id = p_group and status = 'active';
  return cid;
end;
$$;

-- Events after p_since_version, oldest first (catching up after a gap, timelapse).
create function public.get_canvas_events(
  p_canvas uuid, p_since_version bigint default 0, p_limit int default 500
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if not public.is_canvas_member(p_canvas) then raise exception 'not_found'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'x', e.x, 'y', e.y, 'color', e.color, 'user_id', e.user_id,
             'version', e.version, 'at', e.created_at)
           order by e.version)
    from (
      select * from public.canvas_events
      where canvas_id = p_canvas and version > p_since_version
      order by version
      limit least(greatest(p_limit, 1), 1000)
    ) e
  ), '[]'::jsonb);
end;
$$;

-- Paint up to 10 pixels for 1 Ink each. p_pixels = [{"x":3,"y":4,"c":5}, ...].
-- p_batch is chosen by the app; sending the same batch again after a dropped
-- connection does not charge twice. A pixel that already has that colour is skipped
-- and costs nothing. All or nothing.
create function public.paint_pixels(p_canvas uuid, p_batch uuid, p_pixels jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c public.canvases;
  palette_size int;
  item jsonb;
  px int;
  py int;
  pc int;
  idx int;
  prev int;
  changed int := 0;
  v bigint;
  pix bytea;
  ink_reason text := 'paint:' || p_canvas || ':' || p_batch;
  w public.ink_wallets;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if jsonb_typeof(p_pixels) is distinct from 'array'
     or jsonb_array_length(p_pixels) = 0 then
    raise exception 'bad_pixel';
  end if;
  if jsonb_array_length(p_pixels) > 10 then raise exception 'too_many_pixels'; end if;

  -- Lock order is always wallet, then canvas, so two painters cannot deadlock.
  w := public.touch_wallet(me);
  select * into c from public.canvases where id = p_canvas for update;
  if c.id is null or not public.is_group_member(c.group_id) then
    raise exception 'not_found';
  end if;
  if c.status <> 'active' then raise exception 'canvas_locked'; end if;

  -- Same batch again: nothing to do, report where things stand.
  if exists (select 1 from public.ink_ledger
             where user_id = me and reason = ink_reason) then
    return jsonb_build_object(
      'version', c.version, 'ink_balance', w.balance, 'painted', 0, 'repeat', true);
  end if;

  select array_length(pal.colors, 1) into palette_size
  from public.palettes pal where id = c.palette_id;

  -- A person cannot paint more than 30 pixels a minute (stops scripts).
  if (select count(*) from public.canvas_events
      where canvas_id = p_canvas and user_id = me
        and created_at > now() - interval '1 minute')
     + jsonb_array_length(p_pixels) > 30 then
    raise exception 'rate_limited';
  end if;

  pix := c.pixels;
  v := c.version;
  for item in select * from jsonb_array_elements(p_pixels) loop
    if jsonb_typeof(item -> 'x') is distinct from 'number'
       or jsonb_typeof(item -> 'y') is distinct from 'number'
       or jsonb_typeof(item -> 'c') is distinct from 'number' then
      raise exception 'bad_pixel';
    end if;
    px := (item ->> 'x')::int;
    py := (item ->> 'y')::int;
    pc := (item ->> 'c')::int;
    if px < 0 or px >= c.width or py < 0 or py >= c.height
       or pc < 0 or pc >= palette_size then
      raise exception 'bad_pixel';
    end if;
    idx := py * c.width + px;
    prev := get_byte(pix, idx);
    if prev = pc then continue; end if;
    pix := set_byte(pix, idx, pc);
    v := v + 1;
    changed := changed + 1;
    insert into public.canvas_events
      (canvas_id, x, y, color, prev_color, user_id, batch_id, version)
    values (p_canvas, px, py, pc, prev, me, p_batch, v);
  end loop;

  if changed = 0 then
    return jsonb_build_object(
      'version', c.version, 'ink_balance', w.balance, 'painted', 0, 'repeat', false);
  end if;

  update public.canvases set pixels = pix, version = v where id = p_canvas;
  -- Raises insufficient_ink (and undoes everything above) if the wallet is short.
  perform public.ink_change(me, -changed, ink_reason);

  return jsonb_build_object(
    'version', v,
    'ink_balance', (select balance from public.ink_wallets where user_id = me),
    'painted', changed,
    'repeat', false
  );
end;
$$;

-- Owner: start a fresh canvas. The old one is kept (archived) for the record.
create function public.new_canvas(p_group uuid, p_size int, p_palette text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  cid uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if p_size not in (16, 24, 32) then raise exception 'bad_size'; end if;
  if not exists (select 1 from public.palettes where id = p_palette) then
    raise exception 'bad_palette';
  end if;
  -- Hold the group row so two taps cannot make two active canvases.
  perform 1 from public.groups where id = p_group for update;
  update public.canvases set status = 'archived'
    where group_id = p_group and status = 'active';
  insert into public.canvases (group_id, width, height, palette_id, pixels)
  values (p_group, p_size, p_size, p_palette,
          decode(repeat('00', p_size * p_size), 'hex'))
  returning id into cid;
  return cid;
end;
$$;

-- Owner: undo one person's vandalism. Only cells whose latest paint is still theirs
-- go back to what was there before their first paint since p_since. Free, and
-- recorded as the owner's events so everyone's screen follows.
create function public.rollback_user_events(
  p_canvas uuid, p_user uuid, p_since timestamptz
) returns int
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c public.canvases;
  cell record;
  pix bytea;
  v bigint;
  restored int := 0;
  batch uuid := gen_random_uuid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into c from public.canvases where id = p_canvas for update;
  if c.id is null then raise exception 'not_found'; end if;
  if not public.group_is_owner(c.group_id, me) then raise exception 'not_owner'; end if;
  if c.status <> 'active' then raise exception 'canvas_locked'; end if;

  pix := c.pixels;
  v := c.version;
  for cell in
    select e.x, e.y,
           (select f.prev_color from public.canvas_events f
            where f.canvas_id = e.canvas_id and f.x = e.x and f.y = e.y
              and f.user_id = p_user and f.created_at >= p_since
            order by f.version limit 1) as restore_to
    from (
      -- The latest event of each cell...
      select distinct on (x, y) *
      from public.canvas_events
      where canvas_id = p_canvas
      order by x, y, version desc
    ) e
    -- ...if it is that person's and recent enough.
    where e.user_id = p_user and e.created_at >= p_since
  loop
    if get_byte(pix, cell.y * c.width + cell.x) = cell.restore_to then
      continue;
    end if;
    v := v + 1;
    insert into public.canvas_events
      (canvas_id, x, y, color, prev_color, user_id, batch_id, version)
    values (p_canvas, cell.x, cell.y, cell.restore_to,
            get_byte(pix, cell.y * c.width + cell.x), me, batch, v);
    pix := set_byte(pix, cell.y * c.width + cell.x, cell.restore_to);
    restored := restored + 1;
  end loop;

  if restored > 0 then
    update public.canvases set pixels = pix, version = v where id = p_canvas;
  end if;
  return restored;
end;
$$;

revoke all on function
  public.get_canvas(uuid),
  public.get_group_canvas(uuid),
  public.get_canvas_events(uuid, bigint, int),
  public.paint_pixels(uuid, uuid, jsonb),
  public.new_canvas(uuid, int, text),
  public.rollback_user_events(uuid, uuid, timestamptz)
from public, anon;
grant execute on function
  public.get_canvas(uuid),
  public.get_group_canvas(uuid),
  public.get_canvas_events(uuid, bigint, int),
  public.paint_pixels(uuid, uuid, jsonb),
  public.new_canvas(uuid, int, text),
  public.rollback_user_events(uuid, uuid, timestamptz)
to authenticated;

-- Pixels appear on everyone's screen as they are painted (RLS still applies).
alter publication supabase_realtime add table public.canvas_events;
