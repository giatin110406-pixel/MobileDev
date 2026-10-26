-- Post tags (20261026000001_post_tags.sql): readable like the post, written only by the author, only
-- for their friends; a tagged friend gets the post; they can take their name off and it stays off.
-- Run with `npx supabase test db` (needs Docker).
begin;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'author@test.dev'),
  ('00000000-0000-0000-0000-0000000000a2', 'lan@test.dev'),
  ('00000000-0000-0000-0000-0000000000a3', 'stranger@test.dev');
-- the author is friends with Lan only
insert into public.friendships (user_a, user_b) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
-- b1 goes to all friends; b2 goes to nobody (an empty list of recipients)
select public.create_post(
  '00000000-0000-0000-0000-0000000000b1', 'photo',
  '00000000-0000-0000-0000-0000000000a1/b1.jpg', null, '', null, null, null);
select public.create_post(
  '00000000-0000-0000-0000-0000000000b2', 'photo',
  '00000000-0000-0000-0000-0000000000a1/b2.jpg', null, '', null, null, null,
  array[]::uuid[]);

select lives_ok($$select public.set_post_tags('00000000-0000-0000-0000-0000000000b1',
    array['00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a3']::uuid[])$$,
  'the author tags people');
select is((select array_agg(user_id) from public.post_tags
           where post_id = '00000000-0000-0000-0000-0000000000b1'),
          array['00000000-0000-0000-0000-0000000000a2'::uuid],
          'only friends are kept: the stranger is dropped');
select lives_ok($$select public.set_post_tags('00000000-0000-0000-0000-0000000000b1',
    array['00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a2']::uuid[])$$,
  'tagging again with the same list is fine');
select is((select count(*) from public.post_tags)::int, 1, 'and does not duplicate');
select throws_ok($$select public.set_post_tags('00000000-0000-0000-0000-0000000000b1',
    (select array_agg(gen_random_uuid()) from generate_series(1, 21)))$$,
  'too_many_tags', 'a long list is refused');

-- b2 was sent to nobody; tagging Lan sends it to her
select public.set_post_tags('00000000-0000-0000-0000-0000000000b2',
  array['00000000-0000-0000-0000-0000000000a2']::uuid[]);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select is((select count(*) from public.posts
           where id = '00000000-0000-0000-0000-0000000000b2')::int, 1,
          'a tagged friend gets the post');
select throws_ok($$select public.set_post_tags('00000000-0000-0000-0000-0000000000b1',
    array[]::uuid[])$$, 'not_found', 'nobody but the author can change tags');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
select is((select count(*) from public.post_tags)::int, 0, 'a stranger reads nothing');

-- Lan takes her name off b2
select pg_temp.act_as('00000000-0000-0000-0000-0000000000a2');
select lives_ok($$select public.remove_my_tag('00000000-0000-0000-0000-0000000000b2')$$,
  'the tagged friend takes their name off');
select is((select count(*) from public.post_tags
           where post_id = '00000000-0000-0000-0000-0000000000b2')::int, 0, 'the tag is gone');
select is((select count(*) from public.posts
           where id = '00000000-0000-0000-0000-0000000000b2')::int, 1, 'the post stays');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select public.set_post_tags('00000000-0000-0000-0000-0000000000b2',
  array['00000000-0000-0000-0000-0000000000a2']::uuid[]);
select is((select count(*) from public.post_tags
           where post_id = '00000000-0000-0000-0000-0000000000b2')::int, 0,
          'the author cannot put the name back');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a3');
select lives_ok($$select public.remove_my_tag('00000000-0000-0000-0000-0000000000b1')$$,
  'removing a tag you do not have does nothing');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000a1');
select public.delete_post('00000000-0000-0000-0000-0000000000b1');
select throws_ok($$select public.set_post_tags('00000000-0000-0000-0000-0000000000b1',
    array[]::uuid[])$$, 'not_found', 'a deleted post cannot be tagged');

select * from finish();
rollback;
