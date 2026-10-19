-- One-off gift: 10,000 Sunbit for every user.
--
-- Run it by hand in the Supabase SQL editor (Dashboard -> SQL Editor), not as a
-- migration: a migration would also run on every fresh database. It is safe to run
-- twice: a user who already has the ledger row for this gift is skipped.
--
-- To gift again later, change `gift` to a new code (e.g. 'gift:spring2027') and
-- the amount if you like.
do $$
declare
  gift   constant text := 'gift:free10000';
  amount constant int  := 10000;
  u      record;
  given  int := 0;
begin
  for u in
    select p.id
    from public.profiles p
    where not exists (
      select 1 from public.sunbit_ledger l
      where l.user_id = p.id and l.reason = gift
    )
  loop
    -- Makes the player_state row if this user never opened the quest or the shop.
    perform public.touch_player(u.id);

    update public.player_state
      set balance = balance + amount
      where user_id = u.id;

    insert into public.sunbit_ledger (user_id, amount, reason)
    values (u.id, amount, gift);

    given := given + 1;
  end loop;

  raise notice 'Gave % Sunbit to % users', amount, given;
end;
$$;

-- Check: how many users got it, and the total handed out.
-- select count(*), sum(amount) from public.sunbit_ledger where reason = 'gift:free10000';
