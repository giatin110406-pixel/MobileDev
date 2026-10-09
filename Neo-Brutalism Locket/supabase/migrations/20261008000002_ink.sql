-- Ink: the currency for painting the group canvas. Separate from Sunbit.
-- Earned only by finishing the daily quest (+10, once a day because the quest
-- itself pays once a day); spent 1 per pixel (see paint_pixels).
-- Same rules as Sunbit: balance never below 0, an append-only ledger, rows locked
-- while spending, clients may only read.

create table public.ink_wallets (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.ink_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount int not null check (amount <> 0),
  -- quest:<id>:<day>, paint:<canvas>:<batch>, prize:<contest>:<rank>.
  -- Unique per person, so retrying the same action never pays or charges twice.
  reason text not null,
  created_at timestamptz not null default now(),
  unique (user_id, reason)
);
create index ink_ledger_user_idx on public.ink_ledger (user_id, created_at desc);

alter table public.ink_wallets enable row level security;
alter table public.ink_ledger enable row level security;

create policy "players read their own wallet"
  on public.ink_wallets for select to authenticated
  using (user_id = (select auth.uid()));
create policy "players read their own ink ledger"
  on public.ink_ledger for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.ink_wallets, public.ink_ledger to authenticated;

-- The wallet row, created on first use and locked until the end of the transaction.
create function public.touch_wallet(p_user uuid) returns public.ink_wallets
language plpgsql security definer set search_path = '' as $$
declare w public.ink_wallets;
begin
  insert into public.ink_wallets (user_id) values (p_user)
  on conflict (user_id) do nothing;
  select * into w from public.ink_wallets where user_id = p_user for update;
  return w;
end;
$$;
revoke all on function public.touch_wallet(uuid) from public, anon, authenticated;

-- Adds or spends Ink and records why. Returns the new balance. Internal.
-- A reason that was already recorded is a no-op (returns the balance as it is).
create function public.ink_change(p_user uuid, p_amount int, p_reason text)
returns int
language plpgsql security definer set search_path = '' as $$
declare w public.ink_wallets;
begin
  w := public.touch_wallet(p_user);
  if exists (select 1 from public.ink_ledger
             where user_id = p_user and reason = p_reason) then
    return w.balance;
  end if;
  if w.balance + p_amount < 0 then raise exception 'insufficient_ink'; end if;
  update public.ink_wallets
    set balance = balance + p_amount, updated_at = now()
    where user_id = p_user
    returning balance into w.balance;
  insert into public.ink_ledger (user_id, amount, reason)
  values (p_user, p_amount, p_reason);
  return w.balance;
end;
$$;
revoke all on function public.ink_change(uuid, int, text)
  from public, anon, authenticated;

-- player_json: everything the app shows, now with the Ink balance. -------------------
create or replace function public.player_json(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'seed', s.seed,
    'balance', s.balance,
    'ink_balance', coalesce(
      (select w.balance from public.ink_wallets w where w.user_id = s.user_id), 0),
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

-- complete_quest: the same rules as before, plus +10 Ink in the same transaction. ----
create or replace function public.complete_quest(p_day int, p_quest_id text)
returns jsonb
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

  perform public.ink_change(me, 10, 'quest:' || st.quest_day);

  return jsonb_build_object(
    'state', public.player_json(me),
    'streak', new_streak,
    'base', 25,
    'bonus', bonus,
    'ink', 10
  );
end;
$$;

-- Reading my own wallet without a quest (the canvas header uses this).
create function public.get_ink_balance() returns int
language plpgsql security definer set search_path = '' as $$
declare w public.ink_wallets;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  w := public.touch_wallet(auth.uid());
  return w.balance;
end;
$$;
revoke all on function public.get_ink_balance() from public, anon;
grant execute on function public.get_ink_balance() to authenticated;
