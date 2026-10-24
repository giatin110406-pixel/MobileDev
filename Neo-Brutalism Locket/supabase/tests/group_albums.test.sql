-- Event albums (20261023000001_group_albums.sql): members only, own posts only, inside
-- the window, files readable by the group. Run with `npx supabase test db` (needs Docker).
begin;
select plan(20);

-- a = owner, b = member (not a's friend), c = member who blocked a, d = outsider.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev'),
  ('00000000-0000-0000-0000-0000000000a2', 'b@test.dev'),
  ('00000000-0000-0000-0000-0000000000a3', 'c@test.dev'),
  ('00000000-0000-0000-0000-0000000000a4', 'd@test.dev');
insert into public.groups (id, name) values
  ('00000000-0000-0000-0000-0000000000b1', 'Trip');
insert into public.group_members (group_id, user_id, role) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'owner'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a2', 'member'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a3', 'member');
insert into public.blocks (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a1');
-- a's posts: one inside the window, one long before it. b's post inside.
insert into public.posts (id, author_id, media_path, thumb_path, original_path, created_at) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000a1/c1.jpg',
   '00000000-0000-0000-0000-0000000000a1/c1_thumb.jpg',
   '00000000-0000-0000-0000-0000000000a1/c1_orig.jpg', now() - interval '1 hour'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000a1/c2.jpg', null, null, now() - interval '40 days'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a2',
   '00000000-0000-0000-0000-0000000000a2/c3.jpg', null, null, now() - interval '2 hours');

-- The files of a's first post, as storage keeps them.
insert into storage.objects (bucket_id, name) values
  ('media', '00000000-0000-0000-0000-0000000000a1/c1.jpg'),
  ('media', '00000000-0000-0000-0000-0000000000a1/c1_orig.jpg');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create temp table ctx (album uuid);
grant select, insert on ctx to authenticated;

-- creating ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select throws_ok($$select public.create_album('00000000-0000-0000-0000-0000000000b1',
    '  ', now() - interval '1 day', now() + interval '1 day')$$, 'bad_name',
  'an album needs a name');
select throws_ok($$select public.create_album('00000000-0000-0000-0000-0000000000b1',
    'Long', now(), now() + interval '40 days')$$, 'bad_window',
  'an album covers at most 31 days');
select lives_ok($$insert into ctx select public.create_album(
    '00000000-0000-0000-0000-0000000000b1', 'Đà Lạt',
    now() - interval '1 day', now() + interval '1 day')$$,
  'any member can start an album');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a4');
select throws_ok($$select public.create_album('00000000-0000-0000-0000-0000000000b1',
    'Mine', now(), now() + interval '1 day')$$, 'not_member',
  'an outsider cannot');
select is((select count(*) from public.group_albums)::int, 0,
  'and does not see the album');

-- adding --------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select is(public.add_to_album((select album from ctx), '00000000-0000-0000-0000-0000000000c1'),
  true, 'a member adds their own post from the window');
select is(public.add_to_album((select album from ctx), '00000000-0000-0000-0000-0000000000c1'),
  true, 'adding again is fine (outbox retries)');
select is(public.add_to_album((select album from ctx), '00000000-0000-0000-0000-0000000000c2'),
  false, 'a post from outside the window does not go in');
select is(public.add_to_album((select album from ctx), '00000000-0000-0000-0000-0000000000c3'),
  false, 'nor does someone else''s post');

-- reading -------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select is((select count(*) from public.album_items)::int, 1,
  'another member sees the item, without being the author''s friend');
select is((select original_path from public.album_items),
  '00000000-0000-0000-0000-0000000000a1/c1_orig.jpg', 'with the original to download');

select is((select count(*) from storage.objects
           where name like '%/c1%')::int, 2,
  'and may download both files, friend or not');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
select is((select count(*) from public.album_items)::int, 0,
  'a member who blocked the author does not see it');
select is((select count(*) from storage.objects
           where name like '%/c1%')::int, 0, 'nor the files');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a4');
select is((select count(*) from public.album_items)::int, 0, 'an outsider sees nothing');
select is((select count(*) from storage.objects
           where name like '%/c1%')::int, 0, 'and cannot read the files');

-- removing ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
select throws_ok($$select public.remove_from_album((select album from ctx),
    '00000000-0000-0000-0000-0000000000c1')$$, 'not_allowed',
  'a plain member cannot take out someone else''s photo');

-- b started the album, so b may tidy it.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select lives_ok($$select public.remove_from_album((select album from ctx),
    '00000000-0000-0000-0000-0000000000c1')$$, 'the album''s starter can');

-- deleting a post hides it from the album -----------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select public.add_to_album((select album from ctx), '00000000-0000-0000-0000-0000000000c3');
reset role;
update public.posts set deleted_at = now() where id = '00000000-0000-0000-0000-0000000000c3';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select is((select count(*) from public.album_items)::int, 0,
  'a deleted post disappears from the album');

-- the owner deletes the album -----------------------------------------------------------
select lives_ok($$select public.delete_album((select album from ctx))$$,
  'the group''s owner can delete any album');

select * from finish();
rollback;
