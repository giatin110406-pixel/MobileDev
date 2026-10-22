-- Photo search vectors (20261022000001_post_embeddings.sql): as private as the photo, written
-- only by the author, well-formed. Run with `npx supabase test db` (needs Docker).
begin;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'author@test.dev'),
  ('00000000-0000-0000-0000-0000000000e2', 'friend@test.dev'),
  ('00000000-0000-0000-0000-0000000000e3', 'stranger@test.dev');
insert into public.friendships (user_a, user_b) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e2');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- 1024 bytes as the app sends them (base64)
create function pg_temp.vec(p_byte text) returns text language sql as $$
  select encode(decode(repeat(p_byte, 1024), 'hex'), 'base64');
$$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
select lives_ok($$select public.create_post(
    '00000000-0000-0000-0000-0000000000f1', 'photo',
    '00000000-0000-0000-0000-0000000000e1/f1.jpg', null, '', null, null, null, null, null,
    pg_temp.vec('11'))$$, 'a post can be created with its vector');
select lives_ok($$select public.create_post(
    '00000000-0000-0000-0000-0000000000f2', 'photo',
    '00000000-0000-0000-0000-0000000000e1/f2.jpg', null, '', null, null, null)$$,
  'and without one (old apps, failed encode)');
select throws_ok($$select public.create_post(
    '00000000-0000-0000-0000-0000000000f3', 'photo',
    '00000000-0000-0000-0000-0000000000e1/f3.jpg', null, '', null, null, null, null, null,
    encode(decode('0011', 'hex'), 'base64'))$$, 'bad_embedding', 'a vector of the wrong size is refused');
select throws_ok($$select public.set_post_embedding('00000000-0000-0000-0000-0000000000f2',
    'not base64 !!')$$, 'bad_embedding', 'text that is not base64 is refused');
select lives_ok($$select public.set_post_embedding('00000000-0000-0000-0000-0000000000f2',
    pg_temp.vec('22'))$$, 'the author fills in an old post');
select is((select count(*) from public.post_embeddings())::int, 2, 'the author sees both vectors');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e2');
select is((select embedding from public.post_embeddings()
           where id = '00000000-0000-0000-0000-0000000000f1'),
          pg_temp.vec('11'), 'a recipient gets the vector as it was sent');
select is((select count(*) from public.post_embeddings(
             (select embedded_at from public.post_embeddings()
              where id = '00000000-0000-0000-0000-0000000000f1'),
             '00000000-0000-0000-0000-0000000000f1'))::int,
          1, 'paging returns only what came after the cursor');
select throws_ok($$select public.set_post_embedding('00000000-0000-0000-0000-0000000000f1',
    pg_temp.vec('33'))$$, 'not_found', 'nobody but the author can change a vector');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e3');
select is((select count(*) from public.post_embeddings())::int, 0, 'a stranger gets nothing');
select is((select count(*) from public.visible_embedding_ids())::int, 0,
  'not even the ids');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
select public.delete_post('00000000-0000-0000-0000-0000000000f1');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e2');
select is((select array_agg(id) from public.visible_embedding_ids()),
          array['00000000-0000-0000-0000-0000000000f2'::uuid],
          'a deleted post drops out, so phones forget its vector');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e3');
select throws_ok($$select public.set_post_embedding('00000000-0000-0000-0000-0000000000f2',
    pg_temp.vec('44'))$$, 'not_found', 'a stranger cannot write either');

select * from finish();
rollback;
