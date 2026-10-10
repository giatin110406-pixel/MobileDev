-- The winning paintings go on sale as profile banners.
--
-- When a contest is finalized, each of the three winning entries becomes a shop item
-- (a banner made of the painting):
--     first place 300 Sunbit, second 220, third 150; 100 copies each;
--     20% of every sale is shared equally among the people of the winning group
--     (at least 1 Sunbit each), the rest leaves the game (a Sunbit sink).
-- Every person of the winning group gets their own copy for free.
-- The banner is pixel art drawn by the app from the entry (no file, no NFT, no
-- real money: Sunbit only).

alter table public.shop_items
  add column source_entry_id uuid references public.contest_entries (id) on delete set null,
  add column title text,
  add column stock int check (stock is null or stock > 0),
  add column sold int not null default 0 check (sold >= 0),
  add column royalty_percent int not null default 0
    check (royalty_percent between 0 and 50);

create index shop_items_source_idx on public.shop_items (source_entry_id)
  where source_entry_id is not null;

-- Makes the shop items of a contest's winners and gives each winner a copy. Safe to
-- run again (nothing is made twice).
create function public.contest_make_shop_items(p_contest uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.shop_items
    (id, kind, rarity, theme, price, source_entry_id, title, stock, royalty_percent)
  select 'contest_' || cr.entry_id,
         'banner',
         case cr.rank when 1 then 'legendary' else 'rare' end,
         case th.category when 'vangogh' then 'vanGogh' else 'pixel' end,
         (array[300, 220, 150])[cr.rank],
         e.id,
         e.group_name,
         100,
         20
  from public.contest_results cr
  join public.contest_entries e on e.id = cr.entry_id
  join public.contests c on c.id = cr.contest_id
  join public.contest_themes th on th.id = c.theme_id
  where cr.contest_id = p_contest
  on conflict (id) do nothing;

  insert into public.inventory (user_id, item_id)
  select cp.user_id, 'contest_' || cr.entry_id
  from public.contest_results cr
  join public.contest_entries e on e.id = cr.entry_id
  join public.contest_participants cp
    on cp.contest_id = cr.contest_id and cp.group_id = e.group_id
  where cr.contest_id = p_contest
  on conflict do nothing;
end;
$$;
revoke all on function public.contest_make_shop_items(uuid)
  from public, anon, authenticated;

create or replace function public.finalize_contest(p_contest uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  ct public.contests;
  win record;
  member_row record;
  min_votes int := public.cfg_int('min_votes');
  min_rank int := public.cfg_int('min_votes_for_rank');
  age_days int := public.cfg_int('min_account_age_days');
  bayes int := public.cfg_int('bayes_c');
  sunbit int[] := array[150, 100, 50];
  ink int[] := array[30, 20, 10];
begin
  select * into ct from public.contests where id = p_contest for update;
  if ct.id is null or ct.finalized_at is not null then return; end if;

  insert into public.contest_results (contest_id, rank, entry_id, score, vote_count)
  with entries as (
    select id, group_id, seq from public.contest_entries
    where contest_id = ct.id and status = 'accepted'
  ),
  raters as (
    -- Each person in an entering group, and how many entries they were allowed to rate.
    select u.user_id,
           least(min_votes, (
             select count(*) from entries e
             where e.group_id not in (
               select pp.group_id from public.contest_participants pp
               where pp.contest_id = ct.id and pp.user_id = u.user_id))) as needed
    from (select distinct user_id from public.contest_participants
          where contest_id = ct.id) u
  ),
  cast_votes as (
    select v.voter_id, count(*) as cast_count
    from public.entry_votes v join entries e on e.id = v.entry_id
    group by v.voter_id
  ),
  valid_raters as (
    select r.user_id from raters r
    left join cast_votes cv on cv.voter_id = r.user_id
    where coalesce(cv.cast_count, 0) >= r.needed
      and exists (
        select 1 from auth.users au
        where au.id = r.user_id
          and au.created_at <= ct.ends_at - make_interval(days => age_days))
  ),
  counted as (
    select v.entry_id, v.score
    from public.entry_votes v
    join entries e on e.id = v.entry_id
    join valid_raters vr on vr.user_id = v.voter_id
  ),
  mean as (select coalesce(avg(score), 0) as m from counted),
  stats as (
    select e.id as entry_id, e.seq, count(k.score) as n, coalesce(sum(k.score), 0) as s
    from entries e left join counted k on k.entry_id = e.id
    group by e.id, e.seq
  ),
  ranked as (
    select st.entry_id, st.n, st.seq,
           (bayes * mean.m + st.s) / (bayes + st.n) as score
    from stats st, mean
    where st.n >= min_rank
  )
  select ct.id,
         (row_number() over (order by score desc, n desc, seq asc))::int,
         entry_id, round(score::numeric, 4), n::int
  from ranked
  order by score desc, n desc, seq asc
  limit 3;

  -- Prizes for every person who was in a winning group when it entered.
  for win in
    select cr.rank, e.group_id
    from public.contest_results cr
    join public.contest_entries e on e.id = cr.entry_id
    where cr.contest_id = ct.id
  loop
    for member_row in
      select user_id from public.contest_participants
      where contest_id = ct.id and group_id = win.group_id
    loop
      perform public.touch_player(member_row.user_id);
      update public.player_state
        set balance = balance + sunbit[win.rank]
        where user_id = member_row.user_id;
      insert into public.sunbit_ledger (user_id, amount, reason)
      values (member_row.user_id, sunbit[win.rank],
              'prize:' || ct.week_key || ':' || win.rank);
      perform public.ink_change(
        member_row.user_id, ink[win.rank], 'prize:' || ct.id || ':' || win.rank);
    end loop;
  end loop;

  perform public.contest_make_shop_items(ct.id);

  update public.contests
    set finalized_at = now(), status = 'finalized'
    where id = ct.id;
end;
$$;

-- Contests that were finalized before this migration.
select public.contest_make_shop_items(id) from public.contests
where finalized_at is not null;

-- Buying: the same rules as before, plus limited copies and the royalty. ---------------
-- Errors: not_signed_in, not_found, already_owned, sold_out, insufficient_funds.
create or replace function public.buy_item(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  item public.shop_items;
  st public.player_state;
  recipients uuid[] := '{}';
  who uuid;
  pool int;
  share int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  -- Locking the item makes "copies left" exact when two people buy the last one.
  select * into item from public.shop_items where id = p_item for update;
  if item.id is null then raise exception 'not_found'; end if;
  if item.source_entry_id is not null and not exists (
    select 1 from public.contest_entries
    where id = item.source_entry_id and status = 'accepted') then
    raise exception 'not_found'; -- an entry that was hidden is not for sale
  end if;

  if item.source_entry_id is not null and item.royalty_percent > 0 then
    select coalesce(array_agg(cp.user_id order by cp.user_id), '{}') into recipients
    from public.contest_entries e
    join public.contest_participants cp
      on cp.contest_id = e.contest_id and cp.group_id = e.group_id
    where e.id = item.source_entry_id and cp.user_id <> me;
  end if;

  -- Lock everybody involved in the same order, so two buyers can never wait on
  -- each other.
  for who in
    select distinct u from unnest(recipients || me) u order by u
  loop
    perform public.touch_player(who);
  end loop;
  st := public.touch_player(me);

  if exists (
    select 1 from public.inventory where user_id = me and item_id = item.id
  ) then
    raise exception 'already_owned';
  end if;
  if item.stock is not null and item.sold >= item.stock then
    raise exception 'sold_out';
  end if;
  if st.balance < item.price then raise exception 'insufficient_funds'; end if;

  update public.player_state set balance = balance - item.price where user_id = me;
  insert into public.sunbit_ledger (user_id, amount, reason)
  values (me, -item.price, 'buy:' || item.id);
  insert into public.inventory (user_id, item_id) values (me, item.id);
  if item.stock is not null then
    update public.shop_items set sold = sold + 1 where id = item.id;
  end if;

  if coalesce(array_length(recipients, 1), 0) > 0 then
    pool := item.price * item.royalty_percent / 100;
    share := greatest(pool / array_length(recipients, 1), 1);
    foreach who in array recipients loop
      update public.player_state set balance = balance + share where user_id = who;
      insert into public.sunbit_ledger (user_id, amount, reason)
      values (who, share, 'royalty:' || item.id);
    end loop;
  end if;
  return public.player_json(me);
end;
$$;

-- The shop's Gallery shelf: the winning paintings of the contests. ------------------------
create function public.get_contest_shop() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.contest_tick();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id,
      'title', s.title,
      'rarity', s.rarity,
      'theme', s.theme,
      'price', s.price,
      'stock', s.stock,
      'sold', s.sold,
      'rank', cr.rank,
      'week_key', c.week_key,
      'title_vi', th.title_vi,
      'title_en', th.title_en,
      'owned', exists (select 1 from public.inventory i
                       where i.user_id = me and i.item_id = s.id)
    ) order by c.starts_at desc, cr.rank)
    from public.shop_items s
    join public.contest_results cr on cr.entry_id = s.source_entry_id
    join public.contests c on c.id = cr.contest_id
    join public.contest_themes th on th.id = c.theme_id
    join public.contest_entries e on e.id = s.source_entry_id
    where s.source_entry_id is not null and e.status = 'accepted'
  ), '[]'::jsonb);
end;
$$;

-- The picture of a painting-banner, for drawing it on a profile.
create function public.get_banner_art(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e public.contest_entries;
  pal public.palettes;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select ce.* into e
  from public.shop_items s
  join public.contest_entries ce on ce.id = s.source_entry_id
  where s.id = p_item and ce.status = 'accepted';
  if e.id is null then raise exception 'not_found'; end if;
  select * into pal from public.palettes where id = e.palette_id;
  return jsonb_build_object(
    'width', e.width,
    'height', e.height,
    'palette', to_jsonb(pal.colors),
    'pixels', replace(encode(e.pixels, 'base64'), E'\n', ''),
    'group_name', e.group_name);
end;
$$;

revoke all on function public.get_contest_shop(), public.get_banner_art(text)
  from public, anon;
grant execute on function public.get_contest_shop(), public.get_banner_art(text)
  to authenticated;
