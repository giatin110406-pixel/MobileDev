-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
begin;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'sam@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'tess@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'uma@test.dev');
update public.profiles set username = lower(split_part(u.email, '@', 1))
  from auth.users u where u.id = profiles.id;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- sam and tess are friends and sam sent tess a post -------------------------------------------
reset role;
insert into public.friendships values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2');
insert into public.posts (id, author_id, media_path)
  values ('00000000-0000-0000-0000-0000000000f1',
          '00000000-0000-0000-0000-0000000000c1', 'c1/f1.jpg');
insert into public.post_recipients (post_id, user_id)
  values ('00000000-0000-0000-0000-0000000000f1',
          '00000000-0000-0000-0000-0000000000c2');

-- reporting ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c2');
select lives_ok($$select public.report_content(null,
  '00000000-0000-0000-0000-0000000000f1', 'spam', 'ads')$$, 'a recipient can report a post');
select is((select count(*)::int from public.reports), 0,
  'reports cannot be read from the app');
select throws_ok($$select public.report_content(null,
  '00000000-0000-0000-0000-0000000000f1', 'nonsense')$$, 'bad_reason', null,
  'only known reasons');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c3');
select throws_ok($$select public.report_content(null,
  '00000000-0000-0000-0000-0000000000f1', 'spam')$$, 'not_found', null,
  'a stranger cannot report a post they never received');

-- blocking --------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c2');
select throws_ok($$select public.block_user('00000000-0000-0000-0000-0000000000c2')$$,
  'self', null, 'you cannot block yourself');
select lives_ok($$select public.block_user('00000000-0000-0000-0000-0000000000c1')$$,
  'blocking works');
select is((select count(*)::int from public.friendships), 0, 'blocking ends the friendship');
select is((select count(*)::int from public.post_recipients), 0,
  'and hides the posts they sent');
select throws_ok($$select public.send_message('00000000-0000-0000-0000-0000000000c1', 'hi')$$,
  'not_found', null, 'a blocked person cannot be messaged');
select lives_ok($$select public.unblock_user('00000000-0000-0000-0000-0000000000c1')$$,
  'unblocking works');

-- deleting the account ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c3');
select public.delete_my_account();
reset role;
select is((select count(*)::int from public.profiles
  where id = '00000000-0000-0000-0000-0000000000c3'), 0,
  'deleting the account removes the profile too');

select * from finish();
rollback;
