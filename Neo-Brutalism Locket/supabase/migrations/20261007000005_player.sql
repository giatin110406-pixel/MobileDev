-- Daily quest, streak, Sunbit and the shop, kept on the server.
-- The server decides what is allowed (3 tries a day, one reward a day, never
-- negative Sunbit, items owned for good); the app only asks.
-- Days are counted in Vietnam time (UTC+7, no daylight saving).

-- What the shop sells. Keep in step with lib/features/shop/shop_catalog.dart
-- (a test compares them).
create table public.shop_items (
  id text primary key,
  kind text not null check (kind in ('frame', 'banner')),
  rarity text not null check (rarity in ('common', 'rare', 'legendary')),
  theme text not null check (theme in ('vanGogh', 'pixel')),
  price int not null check (price between 50 and 500)
);

insert into public.shop_items (id, kind, rarity, theme, price) values
  ('frame_sunflower',     'frame',  'legendary', 'vanGogh', 450),
  ('frame_brush',         'frame',  'common',    'vanGogh',  60),
  ('frame_pixel',         'frame',  'common',    'pixel',    50),
  ('frame_hearts',        'frame',  'rare',      'pixel',   150),
  ('frame_gold_coins',    'frame',  'legendary', 'pixel',   400),
  ('banner_starry_night', 'banner', 'legendary', 'vanGogh', 500),
  ('banner_wheat_field',  'banner', 'rare',      'vanGogh', 180),
  ('banner_almond',       'banner', 'common',    'vanGogh',  80),
  ('banner_retro_sky',    'banner', 'rare',      'pixel',   220),
  ('banner_space',        'banner', 'common',    'pixel',   100);

create table public.player_state (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  -- Picks this person's own order of daily quests.
  seed int not null,
  balance int not null default 0 check (balance >= 0),
  streak int not null default 0 check (streak >= 0),
  last_completed_day int,
  -- The day failed_attempts / passed_photo_id belong to.
  quest_day int,
  failed_attempts int not null default 0 check (failed_attempts >= 0),
  -- Set when today's photo passed the check and is waiting to be posted.
  passed_photo_id text,
  music_muted boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.sunbit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount int not null check (amount <> 0),
  -- A short code: quest:<id>, streak:<days>, buy:<item>.
  reason text not null,
  created_at timestamptz not null default now()
);
create index sunbit_ledger_user_idx
  on public.sunbit_ledger (user_id, created_at desc);

create table public.inventory (
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_id text not null references public.shop_items (id),
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

alter table public.shop_items enable row level security;
alter table public.player_state enable row level security;
alter table public.sunbit_ledger enable row level security;
alter table public.inventory enable row level security;

create policy "everyone reads the shop"
  on public.shop_items for select to authenticated using (true);
create policy "players read their own state"
  on public.player_state for select to authenticated
  using (user_id = (select auth.uid()));
create policy "players read their own ledger"
  on public.sunbit_ledger for select to authenticated
  using (user_id = (select auth.uid()));
create policy "players read their own inventory"
  on public.inventory for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.shop_items, public.player_state,
  public.sunbit_ledger, public.inventory to authenticated;

-- Helpers (internal) ---------------------------------------------------------------------
-- Days since 1970-01-01 in Vietnam time. A new day starts at 00:00 there.
create function public.vietnam_today() returns int
language sql stable as $$
  select ((now() at time zone 'Asia/Ho_Chi_Minh')::date - date '1970-01-01')
$$;

-- The player's row, created on first use and moved to today (tries reset,
-- yesterday's unposted photo forgotten). The row stays locked until the end
-- of the transaction, so two taps cannot spend the same Sunbit twice.
create function public.touch_player(p_user uuid) returns public.player_state
language plpgsql security definer set search_path = '' as $$
declare
  today int := public.vietnam_today();
  st public.player_state;
begin
  insert into public.player_state (user_id, seed, quest_day)
  values (p_user, floor(random() * 2147483646)::int + 1, today)
  on conflict (user_id) do nothing;

  select * into st from public.player_state where user_id = p_user for update;
  if st.quest_day is distinct from today then
    update public.player_state
      set quest_day = today, failed_attempts = 0, passed_photo_id = null
      where user_id = p_user
      returning * into st;
  end if;
  return st;
end;
$$;

-- Everything the app shows, as one JSON document.
create function public.player_json(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'seed', s.seed,
    'balance', s.balance,
    'streak', s.streak,
    'last_completed_day', s.last_completed_day,
    'quest_day', s.quest_day,
    'failed_attempts', s.failed_attempts,
    'passed_photo_id', s.passed_photo_id,
    'music_muted', s.music_muted,
    'today', public.vietnam_today(),
    'frame_id', p.frame_id,
    'banner_id', p.banner_id,
    'owned', coalesce(
      (select jsonb_agg(i.item_id) from public.inventory i
       where i.user_id = s.user_id),
      '[]'::jsonb),
    'ledger', coalesce(
      (select jsonb_agg(
         jsonb_build_object(
           'amount', l.amount, 'reason', l.reason, 'at', l.created_at)
         order by l.created_at)
       from (select * from public.sunbit_ledger
             where user_id = s.user_id
             order by created_at desc limit 100) l),
      '[]'::jsonb)
  )
  from public.player_state s
  join public.profiles p on p.id = s.user_id
  where s.user_id = p_user
$$;

revoke all on function public.touch_player(uuid), public.player_json(uuid)
  from public, anon, authenticated;

-- RPCs -----------------------------------------------------------------------------------
-- Errors (message): not_signed_in, already_done, no_attempts, not_passed,
-- expired, not_found, already_owned, insufficient_funds, not_owned, bad_kind.

create function public.get_player_state() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  perform public.touch_player(auth.uid());
  return public.player_json(auth.uid());
end;
$$;

-- A shot of today's quest: it did not match (costs a try) or it passed (the
-- photo can now be posted). No tries left or already rewarded: refused.
create function public.record_quest_attempt(
  p_passed boolean,
  p_photo_id text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  st public.player_state;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  st := public.touch_player(me);
  if st.last_completed_day = st.quest_day then raise exception 'already_done'; end if;
  if st.failed_attempts >= 3 then raise exception 'no_attempts'; end if;
  if p_passed then
    update public.player_state
      set passed_photo_id = coalesce(nullif(p_photo_id, ''), 'passed')
      where user_id = me;
  else
    update public.player_state
      set failed_attempts = failed_attempts + 1
      where user_id = me;
  end if;
  return public.player_json(me);
end;
$$;

-- Posting today's quest: +25 Sunbit, +50 more when the streak reaches a
-- multiple of 7. One reward per day; p_day must still be today in Vietnam.
create function public.complete_quest(p_day int, p_quest_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  st public.player_state;
  new_streak int;
  bonus int := 0;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  st := public.touch_player(me);
  if p_day is distinct from st.quest_day then raise exception 'expired'; end if;
  if st.last_completed_day = st.quest_day then raise exception 'already_done'; end if;
  if st.passed_photo_id is null then raise exception 'not_passed'; end if;

  new_streak := case
    when st.last_completed_day = st.quest_day - 1 then st.streak + 1
    else 1
  end;
  if new_streak % 7 = 0 then bonus := 50; end if;

  update public.player_state
    set balance = balance + 25 + bonus,
        streak = new_streak,
        last_completed_day = st.quest_day,
        passed_photo_id = null
    where user_id = me;
  insert into public.sunbit_ledger (user_id, amount, reason)
  values (me, 25, 'quest:' || left(coalesce(p_quest_id, ''), 40));
  if bonus > 0 then
    insert into public.sunbit_ledger (user_id, amount, reason)
    values (me, bonus, 'streak:' || new_streak);
  end if;

  return jsonb_build_object(
    'state', public.player_json(me),
    'streak', new_streak,
    'base', 25,
    'bonus', bonus
  );
end;
$$;

create function public.buy_item(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  item public.shop_items;
  st public.player_state;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into item from public.shop_items where id = p_item;
  if item.id is null then raise exception 'not_found'; end if;
  st := public.touch_player(me);
  if exists (
    select 1 from public.inventory where user_id = me and item_id = item.id
  ) then
    raise exception 'already_owned';
  end if;
  if st.balance < item.price then raise exception 'insufficient_funds'; end if;

  update public.player_state set balance = balance - item.price where user_id = me;
  insert into public.sunbit_ledger (user_id, amount, reason)
  values (me, -item.price, 'buy:' || item.id);
  insert into public.inventory (user_id, item_id) values (me, item.id);
  return public.player_json(me);
end;
$$;

-- Wearing something I own. It replaces whatever of its kind I wore. Free.
create function public.equip_item(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  item public.shop_items;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into item from public.shop_items where id = p_item;
  if item.id is null then raise exception 'not_found'; end if;
  if not exists (
    select 1 from public.inventory where user_id = me and item_id = item.id
  ) then
    raise exception 'not_owned';
  end if;
  perform public.touch_player(me);
  if item.kind = 'frame' then
    update public.profiles set frame_id = item.id where id = me;
  else
    update public.profiles set banner_id = item.id where id = me;
  end if;
  return public.player_json(me);
end;
$$;

create function public.unequip_item(p_kind text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.touch_player(me);
  if p_kind = 'frame' then
    update public.profiles set frame_id = null where id = me;
  elsif p_kind = 'banner' then
    update public.profiles set banner_id = null where id = me;
  else
    raise exception 'bad_kind';
  end if;
  return public.player_json(me);
end;
$$;

create function public.set_music_muted(p_muted boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  perform public.touch_player(auth.uid());
  update public.player_state set music_muted = p_muted where user_id = auth.uid();
  return public.player_json(auth.uid());
end;
$$;

revoke all on function
  public.get_player_state(),
  public.record_quest_attempt(boolean, text),
  public.complete_quest(int, text),
  public.buy_item(text),
  public.equip_item(text),
  public.unequip_item(text),
  public.set_music_muted(boolean)
from public, anon;
grant execute on function
  public.get_player_state(),
  public.record_quest_attempt(boolean, text),
  public.complete_quest(int, text),
  public.buy_item(text),
  public.equip_item(text),
  public.unequip_item(text),
  public.set_music_muted(boolean)
to authenticated;
