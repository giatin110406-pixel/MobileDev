-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
begin;
select plan(20);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'quinn@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'rae@test.dev');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');

-- first look ---------------------------------------------------------------------------
select is((public.get_player_state() ->> 'balance')::int, 0, 'a new player has no Sunbit');
select is(public.get_player_state() ->> 'today', public.vietnam_today()::text,
  'the server says which Vietnam day it is');

-- tries ---------------------------------------------------------------------------------
select is((public.record_quest_attempt(false) ->> 'failed_attempts')::int, 1, 'a miss costs a try');
select public.record_quest_attempt(false);
select public.record_quest_attempt(false);
select throws_ok($$select public.record_quest_attempt(false)$$, 'no_attempts',
  null, 'after 3 misses there are no tries left');
select throws_ok($$select public.complete_quest(public.vietnam_today(), 'vg_grapes')$$,
  'not_passed', null, 'cannot be rewarded without a passed photo');

-- a new day gives 3 fresh tries -------------------------------------------------------------
reset role;
update public.player_state set quest_day = public.vietnam_today() - 1
  where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select is((public.get_player_state() ->> 'failed_attempts')::int, 0,
  'tries come back the next day');

-- completing ------------------------------------------------------------------------------------
select public.record_quest_attempt(true, 'photo-1');
select throws_ok($$select public.complete_quest(public.vietnam_today() - 1, 'vg_grapes')$$,
  'expired', null, 'yesterday''s quest cannot be posted');
select is(public.complete_quest(public.vietnam_today(), 'vg_grapes') ->> 'base', '25',
  'a quest pays 25 Sunbit');
select is((public.get_player_state() ->> 'streak')::int, 1, 'the first day starts a streak');
select throws_ok($$select public.complete_quest(public.vietnam_today(), 'vg_grapes')$$,
  'already_done', null, 'one reward per day');
select throws_ok($$select public.record_quest_attempt(true, 'photo-2')$$,
  'already_done', null, 'no more tries after finishing');

-- streak: day 7 pays a bonus; a missed day resets it -----------------------------------------------
reset role;
update public.player_state set
  streak = 6,
  last_completed_day = public.vietnam_today() - 1,
  quest_day = public.vietnam_today() - 1,
  passed_photo_id = null
  where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select public.record_quest_attempt(true, 'photo-7');
select is((public.complete_quest(public.vietnam_today(), 'q') ->> 'bonus')::int, 50,
  'the 7th day in a row adds 50 Sunbit');

reset role;
update public.player_state set
  streak = 9,
  last_completed_day = public.vietnam_today() - 3,
  quest_day = public.vietnam_today() - 1,
  passed_photo_id = null
  where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select public.record_quest_attempt(true, 'photo-8');
select is((public.complete_quest(public.vietnam_today(), 'q') ->> 'streak')::int, 1,
  'missing days sends the streak back to 1');

-- the shop ----------------------------------------------------------------------------------------
reset role;
update public.player_state set balance = 40
  where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select throws_ok($$select public.buy_item('frame_pixel')$$, 'insufficient_funds',
  null, 'not enough Sunbit');
select is((public.get_player_state() ->> 'balance')::int, 40, 'a refused purchase costs nothing');

reset role;
update public.player_state set balance = 120
  where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select is((public.buy_item('frame_pixel') ->> 'balance')::int, 70, 'buying takes the price');
select throws_ok($$select public.buy_item('frame_pixel')$$, 'already_owned',
  null, 'an item is bought once');
select throws_ok($$select public.equip_item('banner_space')$$, 'not_owned',
  null, 'cannot wear what is not owned');
select is(public.equip_item('frame_pixel') ->> 'frame_id', 'frame_pixel', 'wearing an owned frame');

-- privacy: another player sees none of it ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b2');
select is((select count(*)::int from public.sunbit_ledger), 0, 'other people''s ledger is private');

select * from finish();
rollback;
