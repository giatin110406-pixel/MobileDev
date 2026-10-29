-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
begin;
select plan(24);

-- alice and bob are friends, cara is a friend of bob's, dan is a stranger to all of them.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'alice@test.dev'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@test.dev'),
  ('00000000-0000-0000-0000-00000000000c', 'cara@test.dev'),
  ('00000000-0000-0000-0000-00000000000d', 'dan@test.dev');
update public.profiles set
  username = lower(split_part(u.email, '@', 1)),
  display_name = split_part(u.email, '@', 1)
from auth.users u where u.id = profiles.id;
select public.make_friends('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
select public.make_friends('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- alice opens a code ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select lives_ok($$select public.create_pov_code()$$, 'alice opens a code');
select is((select status from public.pov_sessions limit 1), 'pending', 'it waits for a scan');
select is((select host_id from public.pov_sessions limit 1), null, 'nobody is the photographer yet');
select is((select length(code) from public.pov_sessions limit 1), 32, 'the code is long and random');
select lives_ok($$select public.create_pov_code()$$, 'opening the code again gives a new one');
select is((select count(*)::int from public.pov_sessions where status = 'pending'), 1,
  'the old code is closed, only the new one waits');
select is((select count(*)::int from public.pov_sessions where status = 'cancelled'), 1,
  'the old one is cancelled');
select throws_ok($$insert into public.pov_sessions (viewer_id) values
  ('00000000-0000-0000-0000-00000000000a')$$,
  '42501', null, 'clients cannot write sessions directly');

-- nobody else sees it -----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select is((select count(*)::int from public.pov_sessions), 0, 'a stranger does not see the code');

-- bob scans ---------------------------------------------------------------------------------------
reset role;
create temp table the_code as select code from public.pov_sessions where status = 'pending';
grant select on the_code to authenticated;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select throws_ok($$select public.peek_pov_code((select code from the_code))$$, 'not_friends',
  null, 'a stranger scanning learns nothing and cannot join');
select throws_ok($$select public.join_pov((select code from the_code))$$, 'not_friends',
  null, 'and cannot join');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select throws_ok($$select public.join_pov((select code from the_code))$$, 'self',
  null, 'alice cannot scan her own code');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok($$select public.peek_pov_code('nonsense')$$, 'not_found',
  null, 'a code that does not exist is not found');
select is((public.peek_pov_code((select code from the_code)) ->> 'display_name'), 'alice',
  'bob is told whose code it is before he joins');
select is((select status from public.pov_sessions limit 1), 'pending',
  'looking does not join anything');
select lives_ok($$select public.join_pov((select code from the_code))$$, 'bob scans and confirms');
select is((select status from public.pov_sessions where host_id is not null limit 1), 'accepted',
  'the session is accepted');
select throws_ok($$select public.join_pov((select code from the_code))$$, 'not_found',
  null, 'a code works once');

-- during and after --------------------------------------------------------------------------------
select lives_ok($$select public.pov_shot((select id from public.pov_sessions where status = 'accepted'))$$,
  'bob reports a photo');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select lives_ok($$select public.pov_shot((select id from public.pov_sessions where status = 'accepted'))$$,
  'alice trying to count a photo is ignored');
select is((select shots from public.pov_sessions where status = 'accepted'), 1,
  'only bob''s photos count');
select throws_ok($$select public.create_pov_code()$$, 'busy',
  null, 'alice cannot open a code while she is in a session');
select lives_ok($$select public.end_pov((select id from public.pov_sessions where status = 'accepted'))$$,
  'alice ends the session');

-- time runs out ------------------------------------------------------------------------------------
select public.create_pov_code();
reset role;
update public.pov_sessions set expires_at = now() - interval '1 second' where status = 'pending';
create temp table the_old_code as select code from public.pov_sessions where status = 'pending';
grant select on the_old_code to authenticated;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select throws_ok($$select public.join_pov((select code from the_old_code))$$, 'expired',
  null, 'a code that ran out cannot be scanned');

select * from finish();
rollback;
