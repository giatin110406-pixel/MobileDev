-- The winning paintings are a limited-time offer in the banner shop.
--
-- Before: three limited-edition "paintings" (100 copies each). Now: each of the three
-- winning paintings is a profile banner that is on sale for two days after the
-- contest is finalized (config `banner_offer_hours`, 48 by default), then it is gone
-- from the shop for good. Nobody is limited by a number of copies any more, only by
-- time. People who bought one keep it, and it still shows on their profile.
--
-- Everything else stays: prices (300 / 220 / 150 Sunbit), the 20% royalty for the
-- winning group, and the free copy for each member of the winning group.

alter table public.shop_items
  add column available_until timestamptz;

insert into public.contest_config (key, value) values ('banner_offer_hours', '48')
  on conflict (key) do nothing;

-- Banners that were already made: two days after their contest was finalized, and no
-- copy limit.
update public.shop_items s
set available_until = coalesce(c.finalized_at, now()) + interval '2 days',
    stock = null
from public.contest_results cr
join public.contests c on c.id = cr.contest_id
where s.source_entry_id is not null and cr.entry_id = s.source_entry_id;

-- Makes the shop items of a contest's winners and gives each winner a copy. Safe to
-- run again (nothing is made twice).
create or replace function public.contest_make_shop_items(p_contest uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.shop_items
    (id, kind, rarity, theme, price, source_entry_id, title, royalty_percent,
     available_until)
  select 'contest_' || cr.entry_id,
         'banner',
         case cr.rank when 1 then 'legendary' else 'rare' end,
         case th.category when 'vangogh' then 'vanGogh' else 'pixel' end,
         (array[300, 220, 150])[cr.rank],
         e.id,
         e.group_name,
         20,
         public.contest_now() + make_interval(hours => public.cfg_int('banner_offer_hours'))
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

-- Buying: as before, and an offer that has ended cannot be bought.
-- Errors: not_signed_in, not_found, already_owned, offer_ended, sold_out,
-- insufficient_funds.
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
  if item.available_until is not null
     and item.available_until <= public.contest_now() then
    raise exception 'offer_ended';
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

-- The shop's limited-time banners: the winning paintings that are still on sale.
create or replace function public.get_contest_shop() returns jsonb
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
      'ends_at', s.available_until,
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
      and (s.available_until is null or s.available_until > public.contest_now())
  ), '[]'::jsonb);
end;
$$;
