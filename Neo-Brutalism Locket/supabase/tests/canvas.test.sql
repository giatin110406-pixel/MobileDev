-- Run with `npx supabase test db` (needs Docker: `npx supabase start`).
-- Ink and the shared canvas: spending, retries, conflicts, rollback, archiving.
begin;
select plan(25);

-- p = owner, q = member, r = outsider.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000c01', 'p@test.dev'),
  ('00000000-0000-0000-0000-000000000c02', 'q@test.dev'),
  ('00000000-0000-0000-0000-000000000c03', 'r@test.dev');
insert into public.groups (id, name) values
  ('00000000-0000-0000-0000-00000000ff01', 'Painters');
insert into public.group_members (group_id, user_id, role) values
  ('00000000-0000-0000-0000-00000000ff01', '00000000-0000-0000-0000-000000000c01', 'owner'),
  ('00000000-0000-0000-0000-00000000ff01', '00000000-0000-0000-0000-000000000c02', 'member');
-- The new-group trigger made the canvas; remember its id.
create temp table ctx as
  select id as cid from public.canvases
  where group_id = '00000000-0000-0000-0000-00000000ff01';
grant select on ctx to authenticated;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select public.ink_change('00000000-0000-0000-0000-000000000c01', 10, 'quest:test');

-- painting ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000c01');
select is((public.get_canvas((select cid from ctx)) ->> 'ink_balance')::int, 10,
  'the canvas shows my Ink');
select is(
  (public.paint_pixels((select cid from ctx),
     '00000000-0000-0000-0000-0000000000a1',
     '[{"x":0,"y":0,"c":5},{"x":1,"y":0,"c":6}]'::jsonb) ->> 'ink_balance')::int,
  8, 'two pixels cost 2 Ink');
select is(
  (public.paint_pixels((select cid from ctx),
     '00000000-0000-0000-0000-0000000000a1',
     '[{"x":0,"y":0,"c":5},{"x":1,"y":0,"c":6}]'::jsonb) ->> 'repeat')::boolean,
  true, 'sending the same batch again is a no-op');
select is((public.get_canvas((select cid from ctx)) ->> 'ink_balance')::int, 8,
  'a retried batch did not charge twice');
select is(
  (public.paint_pixels((select cid from ctx),
     '00000000-0000-0000-0000-0000000000a2',
     '[{"x":0,"y":0,"c":5}]'::jsonb) ->> 'painted')::int,
  0, 'painting a cell the colour it already is costs nothing');
select throws_ok($$select public.paint_pixels((select cid from ctx),
  '00000000-0000-0000-0000-0000000000a3', '[{"x":32,"y":0,"c":1}]'::jsonb)$$,
  'bad_pixel', null, 'a pixel outside the canvas is refused');
select throws_ok($$select public.paint_pixels((select cid from ctx),
  '00000000-0000-0000-0000-0000000000a4', '[{"x":0,"y":1,"c":16}]'::jsonb)$$,
  'bad_pixel', null, 'a colour outside the palette is refused');
select throws_ok($$select public.paint_pixels((select cid from ctx),
  '00000000-0000-0000-0000-0000000000a5',
  (select jsonb_agg(jsonb_build_object('x', n, 'y', 2, 'c', 1))
   from generate_series(0, 10) n))$$,
  'too_many_pixels', null, 'at most 10 pixels per batch');
select throws_ok($$update public.canvases set pixels = pixels$$, '42501',
  null, 'clients cannot write the canvas directly');

-- only members; no Ink, no paint ---------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000c03');
select throws_ok($$select public.paint_pixels((select cid from ctx),
  '00000000-0000-0000-0000-0000000000b1', '[{"x":2,"y":2,"c":1}]'::jsonb)$$,
  'not_found', null, 'an outsider cannot paint');
select throws_ok($$select public.get_canvas((select cid from ctx))$$, 'not_found',
  null, 'an outsider cannot read the canvas');

select pg_temp.act_as('00000000-0000-0000-0000-000000000c02');
select throws_ok($$select public.paint_pixels((select cid from ctx),
  '00000000-0000-0000-0000-0000000000b2', '[{"x":2,"y":2,"c":1}]'::jsonb)$$,
  'insufficient_ink', null, 'no Ink, no painting');
select is((select version from public.canvases), 2::bigint,
  'a refused batch changed nothing');

-- two people, one cell: the later one wins, both pay ------------------------------------------
reset role;
select public.ink_change('00000000-0000-0000-0000-000000000c02', 5, 'quest:test');
select pg_temp.act_as('00000000-0000-0000-0000-000000000c02');
select is(
  (public.paint_pixels((select cid from ctx),
     '00000000-0000-0000-0000-0000000000b3',
     '[{"x":0,"y":0,"c":9}]'::jsonb) ->> 'ink_balance')::int,
  4, 'the second painter pays too');
reset role;
select is(get_byte((select pixels from public.canvases), 0), 9,
  'the later paint wins the cell');
select is((select count(*)::int from public.canvas_events), 3,
  'every paint is in the event log');

-- rollback (owner only) ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000c02');
select throws_ok($$select public.rollback_user_events((select cid from ctx),
  '00000000-0000-0000-0000-000000000c02', now() - interval '1 hour')$$,
  'not_owner', null, 'a member cannot roll anyone back');
select pg_temp.act_as('00000000-0000-0000-0000-000000000c01');
select is(public.rollback_user_events((select cid from ctx),
  '00000000-0000-0000-0000-000000000c02', now() - interval '1 hour'), 1,
  'the owner rolls back one pixel');
reset role;
select is(get_byte((select pixels from public.canvases), 0), 5,
  'the cell is back to what was there before');

-- a new canvas archives the old one ------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000c01');
select lives_ok($$select public.new_canvas(
  '00000000-0000-0000-0000-00000000ff01', 16, 'vangogh')$$, 'the owner starts a new canvas');
select throws_ok($$select public.paint_pixels((select cid from ctx),
  '00000000-0000-0000-0000-0000000000b4', '[{"x":3,"y":3,"c":2}]'::jsonb)$$,
  'canvas_locked', null, 'the archived canvas cannot be painted');
select is((select count(*)::int from public.canvases where status = 'active'), 1,
  'a group has exactly one active canvas');

-- rate limit -------------------------------------------------------------------------------------
reset role;
insert into public.canvas_events
  (canvas_id, x, y, color, prev_color, user_id, batch_id, version)
select (select id from public.canvases where status = 'active'), 0, 0, 1, 0,
       '00000000-0000-0000-0000-000000000c01', gen_random_uuid(), n
from generate_series(1, 29) n;
select public.ink_change('00000000-0000-0000-0000-000000000c01', 10, 'quest:more');
select pg_temp.act_as('00000000-0000-0000-0000-000000000c01');
select throws_ok($$select public.paint_pixels(
  (select id from public.canvases where status = 'active'),
  '00000000-0000-0000-0000-0000000000b5',
  '[{"x":5,"y":5,"c":2},{"x":6,"y":5,"c":2}]'::jsonb)$$,
  'rate_limited', null, 'more than 30 pixels a minute is refused');

-- the daily quest pays +10 Ink --------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-0000-0000-000000000c03');
select public.record_quest_attempt(true, 'photo1');
select is((public.complete_quest(public.vietnam_today(), 'vg_grapes') ->> 'ink')::int, 10,
  'completing the quest pays 10 Ink');
select is(public.get_ink_balance(), 10, 'and the wallet shows it');

select * from finish();
rollback;
