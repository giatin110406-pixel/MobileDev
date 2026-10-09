-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
-- Groups: owner-only controls, member cap, hand-over, leaving, dissolving.
begin;
select plan(26);

-- o = owner, f1/f2/f3 = o's friends (not friends with each other), s = a stranger.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000a01', 'o@test.dev'),
  ('00000000-0000-0000-0000-000000000a02', 'f1@test.dev'),
  ('00000000-0000-0000-0000-000000000a03', 'f2@test.dev'),
  ('00000000-0000-0000-0000-000000000a04', 's@test.dev'),
  ('00000000-0000-0000-0000-000000000a05', 'f3@test.dev');
update public.profiles set
  username = lower(split_part(u.email, '@', 1)),
  display_name = split_part(u.email, '@', 1)
from auth.users u where u.id = profiles.id;
insert into public.friendships (user_a, user_b) values
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-000000000a02'),
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-000000000a03'),
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-000000000a05');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- create ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000a01');
select public.create_group('Team', 'be kind', 3);
select is((select count(*)::int from public.groups), 1, 'the owner sees the new group');
select is((select role from public.group_members
           where user_id = '00000000-0000-0000-0000-000000000a01'), 'owner',
  'the creator is the owner');
select is((select count(*)::int from public.canvases), 1,
  'a new group comes with a canvas');
select throws_ok($$select public.create_group('', '', 12)$$, 'bad_name',
  null, 'a group needs a name');

-- inviting ----------------------------------------------------------------------------
select lives_ok($$select public.invite_to_group(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a02')$$,
  'the owner invites a friend');
select throws_ok($$select public.invite_to_group(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a04')$$,
  'not_found', null, 'a stranger (not a friend) cannot be invited');
select lives_ok($$select public.invite_to_group(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a03')$$,
  'a second friend is invited');
select throws_ok($$select public.invite_to_group(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a05')$$,
  'member_limit', null, 'pending invites hold seats, so the cap holds (3)');

-- joining and owner-only controls -----------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000a02');
select lives_ok($$select public.respond_group_invite(
  (select id from public.group_invites limit 1), true)$$, 'f1 accepts');
select throws_ok($$select public.update_group(
  (select id from public.groups), 'Mine now', '', 3, null)$$, 'not_owner',
  null, 'a member cannot edit the group');
select throws_ok($$select public.kick_member(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a01')$$,
  'not_owner', null, 'a member cannot kick');
select throws_ok($$select public.invite_to_group(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a03')$$,
  'not_owner', null, 'a member cannot invite');
select throws_ok($$insert into public.group_members (group_id, user_id)
  values ((select id from public.groups), '00000000-0000-0000-0000-000000000a02')$$,
  '42501', null, 'clients cannot write members directly');

select pg_temp.act_as('00000000-0000-0000-0000-000000000a03');
select public.respond_group_invite((select id from public.group_invites limit 1), true);
select is((select count(*)::int from public.group_members), 3,
  'members see all 3 members');

-- chat --------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000a02');
select lives_ok($$select public.send_group_message(
  (select id from public.groups), 'hello team')$$, 'a member chats');
select pg_temp.act_as('00000000-0000-0000-0000-000000000a04');
select is((select count(*)::int from public.groups), 0, 'a stranger sees no groups');
select is((select count(*)::int from public.group_messages), 0,
  'a stranger reads no messages');
select throws_ok($$select public.send_group_message(
  (select id from public.groups), 'hi')$$, 'not_member', null,
  'a stranger cannot chat');

-- history from before I joined stays hidden; blocked people's messages too ---------------
reset role;
insert into public.group_messages (group_id, sender_id, kind, body, created_at)
select id, '00000000-0000-0000-0000-000000000a01', 'text', 'old news',
       now() - interval '1 day'
from public.groups;
select pg_temp.act_as('00000000-0000-0000-0000-000000000a03');
select is((select count(*)::int from public.group_messages where body = 'old news'), 0,
  'messages from before I joined are hidden');
reset role;
insert into public.blocks values
  ('00000000-0000-0000-0000-000000000a03', '00000000-0000-0000-0000-000000000a02');
select pg_temp.act_as('00000000-0000-0000-0000-000000000a03');
select is((select count(*)::int from public.group_messages where body = 'hello team'), 0,
  'messages from someone I blocked are hidden');
reset role;
delete from public.blocks;

-- hand-over, leaving ---------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000a01');
select throws_ok($$select public.leave_group((select id from public.groups))$$,
  'owner_must_transfer', null, 'the owner cannot leave without handing over');
select public.transfer_ownership(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a02');
select is((select role from public.group_members
           where user_id = '00000000-0000-0000-0000-000000000a02'), 'owner',
  'ownership moved to f1');
select throws_ok($$select public.kick_member(
  (select id from public.groups), '00000000-0000-0000-0000-000000000a03')$$,
  'not_owner', null, 'the old owner lost the owner powers');

select pg_temp.act_as('00000000-0000-0000-0000-000000000a03');
select public.leave_group((select id from public.groups));
select is((select count(*)::int from public.groups), 0,
  'someone who left no longer sees the group');

-- dissolving -----------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000a02');
select public.dissolve_group((select id from public.groups));
select is((select count(*)::int from public.groups), 0,
  'a dissolved group disappears for everyone');

-- an owner who deletes their account hands the group to the longest member -----------------------
reset role;
insert into public.groups (id, name) values
  ('00000000-0000-0000-0000-00000000cc01', 'Orphan');
insert into public.group_members (group_id, user_id, role, joined_at) values
  ('00000000-0000-0000-0000-00000000cc01', '00000000-0000-0000-0000-000000000a04',
   'owner', now() - interval '2 days'),
  ('00000000-0000-0000-0000-00000000cc01', '00000000-0000-0000-0000-000000000a05',
   'member', now() - interval '1 day');
delete from auth.users where id = '00000000-0000-0000-0000-000000000a04';
select is((select role from public.group_members
           where user_id = '00000000-0000-0000-0000-000000000a05'), 'owner',
  'deleting the owner''s account promotes the next member');

select * from finish();
rollback;
