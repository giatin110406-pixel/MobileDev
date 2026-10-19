-- Canvases are rectangles in the proportions of a profile banner.
--
-- A banner is 2.5 times as wide as it is tall, and so is a canvas now: a new group
-- starts with a 40 x 16 canvas, and the owner can start another of 30 x 12, 40 x 16
-- or 50 x 20 cells. The winning paintings become banners without being squeezed, and
-- the Gallery hangs them in frames of the same shape.
--
-- Canvases that exist keep their size (the 32 x 32 ones too), and so do the entries
-- already in a Gallery.

-- Every new group gets an empty 40 x 16 canvas.
create or replace function public.new_group_canvas() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.canvases (group_id, width, height, palette_id, pixels)
  values (new.id, 40, 16, 'eightbit', decode(repeat('00', 40 * 16), 'hex'));
  return new;
end;
$$;

-- Owner: start a fresh canvas. The old one is kept (archived) for the record.
-- p_size is the height in cells (12, 16 or 20); the width is 2.5 times that.
create or replace function public.new_canvas(p_group uuid, p_size int, p_palette text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  cid uuid;
  w int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if p_size not in (12, 16, 20) then raise exception 'bad_size'; end if;
  if not exists (select 1 from public.palettes where id = p_palette) then
    raise exception 'bad_palette';
  end if;
  w := p_size * 5 / 2;
  -- Hold the group row so two taps cannot make two active canvases.
  perform 1 from public.groups where id = p_group for update;
  update public.canvases set status = 'archived'
    where group_id = p_group and status = 'active';
  insert into public.canvases (group_id, width, height, palette_id, pixels)
  values (p_group, w, p_size, p_palette, decode(repeat('00', w * p_size), 'hex'))
  returning id into cid;
  return cid;
end;
$$;
