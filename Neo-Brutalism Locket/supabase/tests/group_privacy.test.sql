-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
-- Being in the same group must NOT open anyone's photos, DMs or private data.
begin;
select plan(11);

-- a and b share a group but are not friends. c is a's friend, outside the group.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000b01', 'ann@test.dev'),
  ('00000000-0000-0000-0000-000000000b02', 'ben@test.dev'),
  ('00000000-0000-0000-0000-000000000b03', 'cid@test.dev');
update public.profiles set
  username = lower(split_part(u.email, '@', 1)),
  display_name = split_part(u.email, '@', 1)
from auth.users u where u.id = profiles.id;
insert into public.friendships (user_a, user_b) values
  ('00000000-0000-0000-0000-000000000b01', '00000000-0000-0000-0000-000000000b03');

insert into public.groups (id, name) values
  ('00000000-0000-0000-0000-00000000dd01', 'Shared');
insert into public.group_members (group_id, user_id, role) values
  ('00000000-0000-0000-0000-00000000dd01', '00000000-0000-0000-0000-000000000b01', 'owner'),
  ('00000000-0000-0000-0000-00000000dd01', '00000000-0000-0000-0000-000000000b02', 'member');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ann posts a photo (to her friends) while sharing a group with ben ---------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000b01');
select public.create_post(
  '00000000-0000-0000-0000-00000000ee01', 'photo',
  '00000000-0000-0000-0000-000000000b01/p1.jpg', null, 'hi', null, null, null);

reset role;
select is((select count(*)::int from public.post_recipients
           where user_id = '00000000-0000-0000-0000-000000000b02'), 0,
  'a group-mate is not a recipient of a post');
select is((select count(*)::int from public.post_recipients
           where user_id = '00000000-0000-0000-0000-000000000b03'), 1,
  'the real friend is a recipient');

insert into storage.objects (bucket_id, name)
values ('media', '00000000-0000-0000-0000-000000000b01/p1.jpg');

-- ben, same group, not a friend ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000b02');
select is((select count(*)::int from public.posts), 0,
  'a group-mate cannot read the post');
select is((select count(*)::int from public.post_recipients), 0,
  'a group-mate cannot read recipient rows');
select is((select count(*)::int from storage.objects where bucket_id = 'media'), 0,
  'a group-mate cannot read the photo file');
select throws_ok($$select public.send_message(
  '00000000-0000-0000-0000-000000000b01', 'hey')$$, 'not_found', null,
  'a group-mate cannot send a direct message');
select is((select count(*)::int from public.player_state), 0,
  'a group-mate cannot read the other person''s quest state');
select is((select count(*)::int from public.profiles
           where id = '00000000-0000-0000-0000-000000000b01'), 1,
  'the public profile card is still visible');
select is(public.send_friend_request('ann'), 'sent',
  'a friend request can be sent from inside the group');

-- cid, the friend, still sees it -----------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000b03');
select is((select count(*)::int from public.posts), 1, 'the friend sees the post');
select is((select count(*)::int from storage.objects where bucket_id = 'media'), 1,
  'the friend can read the photo file');

select * from finish();
rollback;
