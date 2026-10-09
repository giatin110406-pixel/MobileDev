-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
begin;
select plan(15);

-- Four people: alice, bob, cara (strangers to each other) and dan.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'alice@test.dev'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@test.dev'),
  ('00000000-0000-0000-0000-00000000000c', 'cara@test.dev'),
  ('00000000-0000-0000-0000-00000000000d', 'dan@test.dev');
update public.profiles set
  username = lower(split_part(u.email, '@', 1)),
  display_name = split_part(u.email, '@', 1)
from auth.users u where u.id = profiles.id;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- alice -> bob ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select is(public.send_friend_request('bob'), 'sent', 'a request is sent');
select throws_ok($$select public.send_friend_request('bob')$$, 'already_sent',
  null, 'the same request cannot be sent twice');
select throws_ok($$select public.send_friend_request('alice')$$, 'self',
  null, 'you cannot add yourself');
select throws_ok($$select public.send_friend_request('nobody')$$, 'not_found',
  null, 'unknown usernames are not found');
select throws_ok($$insert into public.friendships values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')$$,
  '42501', null, 'clients cannot write friendships directly');

-- cara cannot see their request --------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is((select count(*)::int from public.friend_requests), 0,
  'strangers do not see other people''s requests');

-- bob accepts ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select is((select count(*)::int from public.friend_requests where status = 'pending'), 1,
  'bob sees the incoming request');
select lives_ok($$select public.respond_friend_request(
  (select id from public.friend_requests limit 1), true)$$, 'bob accepts');
select is((select count(*)::int from public.friendships), 1, 'they are friends now');
select throws_ok($$select public.send_friend_request('alice')$$, 'already_friends',
  null, 'friends cannot send each other requests');

-- mutual requests become a friendship ------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select public.send_friend_request('dan');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d');
select is(public.send_friend_request('cara'), 'accepted',
  'asking someone who already asked you makes you friends');

-- blocks look like "not found" ---------------------------------------------------------------
reset role;
insert into public.blocks values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select throws_ok($$select public.send_friend_request('bob')$$, 'not_found',
  null, 'a blocked person cannot find the blocker');
select is((select count(*)::int from public.search_profiles('bo')), 0,
  'search hides people who blocked you');

-- the 20-friend limit ----------------------------------------------------------------------------
reset role;
insert into auth.users (id, email)
  select ('10000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
         'f' || n || '@test.dev'
  from generate_series(1, 20) n;
insert into public.friendships (user_a, user_b)
  select least('00000000-0000-0000-0000-00000000000a'::uuid, id),
         greatest('00000000-0000-0000-0000-00000000000a'::uuid, id)
  from auth.users where email like 'f%@test.dev';
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select throws_ok($$select public.send_friend_request('cara')$$, 'friend_limit',
  null, 'nobody can have more than 20 friends');
select is((select count(*)::int from public.search_profiles('a')) >= 0, true,
  'search runs for signed-in users');

select * from finish();
rollback;
