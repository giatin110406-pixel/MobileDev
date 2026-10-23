-- Known holes in the daily quest rewards. These tests describe what SHOULD happen, so they FAIL
-- until the server checks the quest itself (step 1 in the notes). Run with
-- `npx supabase test db` (needs Docker: `npx supabase start`).
begin;
select plan(3);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c3', 'cheat@test.dev');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000c3');

-- Each case runs in its own savepoint so one case cannot change what the next one sees.

-- A pass that was never a photo of the quest must not pay out. Today this succeeds: the client
-- says "passed" with any id and the server believes it.
savepoint fake_pass;
select public.record_quest_attempt(true, 'made-up-photo');
select throws_ok($$select public.complete_quest(public.vietnam_today(), 'vg_grapes')$$,
  null, null, 'a pass the server never checked cannot be rewarded');
rollback to savepoint fake_pass;

-- The quest id must be a real quest in the catalogue. Today any string is accepted.
savepoint unknown_quest;
select public.record_quest_attempt(true, 'photo-1');
select throws_ok($$select public.complete_quest(public.vietnam_today(), 'not_a_quest')$$,
  null, null, 'an unknown quest cannot be posted');
rollback to savepoint unknown_quest;

-- The reward must match the quest the server gave today, not one the client names.
-- (After step 1 this should read today's quest from the server; 'vg_bed' is a stand-in for
-- "some other quest" and should be replaced by a quest the server did not pick.)
savepoint other_quest;
select public.record_quest_attempt(true, 'photo-1');
select throws_ok($$select public.complete_quest(public.vietnam_today(), 'vg_bed')$$,
  null, null, 'a quest that is not today''s cannot be posted');
rollback to savepoint other_quest;

select * from finish();
rollback;
