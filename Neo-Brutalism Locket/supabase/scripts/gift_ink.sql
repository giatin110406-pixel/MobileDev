-- One-off gift: 20,000 Ink (mực) for every user.
--
-- Run it by hand in the Supabase SQL editor (Dashboard -> SQL Editor), not as a
-- migration: a migration would also run on every fresh database. It is safe to run
-- twice: ink_change() skips a user who already has the ledger row for this gift.
--
-- To gift again later, change `gift` to a new code (e.g. 'gift:ink_spring2027') and
-- the amount if you like.
do $$
declare
  gift   constant text := 'gift:ink20000';
  amount constant int  := 20000;
  u      record;
  given  int := 0;
begin
  for u in
    select p.id
    from public.profiles p
    where not exists (
      select 1 from public.ink_ledger l
      where l.user_id = p.id and l.reason = gift
    )
  loop
    -- Creates the wallet if needed, adds the Ink and writes the ledger row.
    perform public.ink_change(u.id, amount, gift);
    given := given + 1;
  end loop;

  raise notice 'Gave % Ink to % users', amount, given;
end;
$$;

-- Check: how many users got it, and the total handed out.
-- select count(*), sum(amount) from public.ink_ledger where reason = 'gift:ink20000';
