-- Weekly contest and the Gallery.
--
-- Every week (Monday 00:00 to the next Monday 00:00, Vietnam time, UTC+7 for
-- everyone) one contest runs on one theme:
--
--   upcoming   from Monday 00:00     the theme is known, groups keep painting
--   open       from Saturday 00:00   a group's owner can submit its canvas
--   judging    when 100 entries are in, or Sunday 12:00, whichever is first:
--              the people of the groups that entered rate and comment
--   closed     from the next Monday 00:00 (= Sunday 23:59:59 ends)
--   finalized  once the results and prizes are written (a few seconds later)
--
-- Only the first 100 submissions get in. The server decides who is first: the
-- contest row is locked for every submission, so number 100 is exactly one entry.
-- A submission is a snapshot of the canvas, taken by the server (the app never
-- sends the picture).
--
-- Nothing here can be written directly by the app. Everything goes through RPCs.
-- The timings are driven by a lazy "tick" that every contest RPC runs first, so the
-- contest moves on even when no scheduler is running; pg_cron runs it as well
-- when the extension is available.

-- Settings that tests (and the owner of the project) may change ------------------------
create table public.contest_config (
  key text primary key,
  value text not null
);
insert into public.contest_config (key, value) values
  ('max_entries', '100'),
  ('min_group_size', '2'),
  ('min_fill_percent', '10'),      -- cells that are not the empty colour
  ('min_votes', '10'),             -- entries a rater must rate for the ratings to count
  ('min_votes_for_rank', '3'),     -- ratings an entry needs to be ranked
  ('min_account_age_days', '7'),
  ('bayes_c', '5'),
  ('comment_cooldown_seconds', '15'),
  ('max_comments', '30'),
  ('report_hide_at', '3');
alter table public.contest_config enable row level security;
-- No policies, no grants: only the project owner reads or changes these.

create function public.cfg_int(p_key text) returns int
language sql stable security definer set search_path = '' as $$
  select value::int from public.contest_config where key = p_key
$$;
revoke all on function public.cfg_int(text) from public, anon, authenticated;

-- "Now" for the contest. Tests can pin it with
--   set local app.contest_now = '2026-10-17 05:00:00+00'
create function public.contest_now() returns timestamptz
language sql stable as $$
  select coalesce(nullif(current_setting('app.contest_now', true), '')::timestamptz, now())
$$;
revoke all on function public.contest_now() from public, anon, authenticated;

-- Monday 00:00 Vietnam time of the week containing p_ts.
create function public.vn_week_start(p_ts timestamptz) returns timestamptz
language sql stable as $$
  select date_trunc('week', p_ts at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh'
$$;
revoke all on function public.vn_week_start(timestamptz) from public, anon, authenticated;

-- Themes: the history of 8-bit games and Van Gogh ---------------------------------------
-- Themes name things and moments (a machine, a painting), never characters or logos
-- that belong to somebody.
create table public.contest_themes (
  id uuid primary key default gen_random_uuid(),
  ord int not null unique,
  category text not null check (category in ('8bit', 'vangogh')),
  title_vi text not null,
  title_en text not null,
  brief_vi text not null,
  brief_en text not null,
  palette_id text not null references public.palettes (id),
  -- The week this theme is (or was last) used, like '2026-W42'. Null = waiting.
  scheduled_week text unique,
  created_at timestamptz not null default now()
);

insert into public.contest_themes
  (ord, category, title_vi, title_en, brief_vi, brief_en, palette_id) values
  (1, 'vangogh', 'Đêm đầy sao', 'The Starry Night',
   'Bầu trời xoáy tròn trên ngôi làng yên ngủ (1889).',
   'A swirling sky above a sleeping village (1889).', 'vangogh'),
  (2, '8bit', 'Máy arcade 1980', 'The 1980s Arcade Cabinet',
   'Chiếc tủ máy chơi game xu đứng giữa tiệm đèn neon.',
   'A coin-op cabinet glowing in a neon arcade.', 'eightbit'),
  (3, 'vangogh', 'Hoa hướng dương', 'Sunflowers',
   'Bình hoa hướng dương vàng rực (1888).',
   'A vase of glowing yellow sunflowers (1888).', 'vangogh'),
  (4, '8bit', 'Hộp băng cartridge', 'The Game Cartridge',
   'Hộp băng game cắm vào máy: nhãn dán, chân tiếp xúc, hơi bụi.',
   'A cartridge pushed into a console: label, contacts, a little dust.', 'eightbit'),
  (5, 'vangogh', 'Quán cà phê ban đêm', 'Café Terrace at Night',
   'Hiên quán vàng ấm dưới bầu trời sao (1888).',
   'A warm yellow terrace under a starry sky (1888).', 'vangogh'),
  (6, '8bit', 'Màn hình CRT', 'The CRT Glow',
   'Màn hình ống đèn sáng trong căn phòng tối.',
   'A tube screen glowing in a dark room.', 'eightbit'),
  (7, 'vangogh', 'Cánh đồng lúa mì và cây bách', 'Wheatfield with Cypresses',
   'Lúa mì gợn sóng, cây bách vươn như ngọn lửa (1889).',
   'Rolling wheat and cypresses rising like flames (1889).', 'vangogh'),
  (8, '8bit', 'Tay cầm đầu tiên', 'The First Gamepad',
   'Chiếc tay cầm với vài nút bấm vuông vắn.',
   'A controller with a handful of square buttons.', 'eightbit'),
  (9, 'vangogh', 'Hoa hạnh nhân', 'Almond Blossom',
   'Cành hoa trắng trên nền trời xanh (1890).',
   'White blossoms against a blue sky (1890).', 'vangogh'),
  (10, '8bit', 'Máy tính trong phòng ngủ', 'The Bedroom Computer',
   'Máy tính 8-bit trên bàn học cạnh cửa sổ.',
   'An 8-bit home computer on a desk by the window.', 'eightbit'),
  (11, 'vangogh', 'Phòng ngủ ở Arles', 'The Bedroom in Arles',
   'Căn phòng nhỏ, giường gỗ và cửa sổ xanh (1888).',
   'A small room, a wooden bed and green shutters (1888).', 'vangogh'),
  (12, '8bit', 'Chip âm thanh', 'The Chiptune Chip',
   'Con chip tạo nên tiếng bíp của cả một thế hệ.',
   'The little chip behind a generation of beeps.', 'eightbit'),
  (13, 'vangogh', 'Chân dung tự hoạ', 'Self-Portrait',
   'Gương mặt nhìn thẳng với những nét cọ xoáy (1889).',
   'A direct gaze in swirling brushstrokes (1889).', 'vangogh'),
  (14, '8bit', 'Tiệm game xu', 'The Coin Arcade',
   'Hàng máy chơi game, đồng xu và những ánh đèn nhấp nháy.',
   'A row of machines, coins and blinking lights.', 'eightbit'),
  (15, 'vangogh', 'Đôi giày cũ', 'A Pair of Shoes',
   'Đôi giày cũ mòn đặt trên sàn gỗ (1886).',
   'A pair of worn shoes on a wooden floor (1886).', 'vangogh'),
  (16, '8bit', 'Đĩa mềm', 'The Floppy Disk',
   'Đĩa mềm vuông với ô trượt kim loại.',
   'A square disk with its metal shutter.', 'eightbit');

-- Contests ------------------------------------------------------------------------------
create table public.contests (
  id uuid primary key default gen_random_uuid(),
  week_key text not null unique,            -- '2026-W42'
  theme_id uuid not null references public.contest_themes (id),
  starts_at timestamptz not null,           -- Monday 00:00 (upcoming)
  opens_at timestamptz not null,            -- Saturday 00:00 (submissions)
  submit_closes_at timestamptz not null,    -- Sunday 12:00 (rating starts at the latest)
  ends_at timestamptz not null,             -- next Monday 00:00 (= Sunday 23:59:59 ends)
  max_entries int not null default 100,
  accepted_count int not null default 0,
  -- Kept in step by the tick; the RPCs compute the phase from the clock themselves.
  status text not null default 'upcoming'
    check (status in ('upcoming', 'open', 'judging', 'closed', 'finalized')),
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  check (starts_at < opens_at and opens_at < submit_closes_at and submit_closes_at < ends_at)
);
create index contests_starts_idx on public.contests (starts_at desc);

create function public.contest_phase(c public.contests) returns text
language sql stable as $$
  select case
    when c.finalized_at is not null then 'finalized'
    when public.contest_now() >= c.ends_at then 'closed'
    when public.contest_now() >= c.submit_closes_at
      or (public.contest_now() >= c.opens_at and c.accepted_count >= c.max_entries)
      then 'judging'
    when public.contest_now() >= c.opens_at then 'open'
    else 'upcoming'
  end
$$;
revoke all on function public.contest_phase(public.contests) from public, anon, authenticated;

-- Entries: a snapshot of a group's canvas ---------------------------------------------------
create table public.contest_entries (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references public.contests (id) on delete cascade,
  -- No foreign keys on the group or the submitter: an entry outlives both.
  group_id uuid not null,
  submitted_by uuid,
  group_name text not null,
  width int not null,
  height int not null,
  palette_id text not null references public.palettes (id),
  pixels bytea not null,
  canvas_version bigint not null,
  seq int not null,                         -- 1..100, the order the server accepted them
  submitted_at timestamptz not null default now(),
  status text not null default 'accepted'
    check (status in ('accepted', 'hidden', 'disqualified')),
  unique (contest_id, group_id),
  unique (contest_id, seq)
);

-- Who may rate: the members of each entering group, as they were at submission.
create table public.contest_participants (
  contest_id uuid not null references public.contests (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null,
  primary key (contest_id, user_id, group_id)
);
create index contest_participants_user_idx on public.contest_participants (user_id);

create table public.entry_votes (
  entry_id uuid not null references public.contest_entries (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  score int not null check (score between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (entry_id, voter_id)
);
create index entry_votes_voter_idx on public.entry_votes (voter_id);

create table public.entry_reactions (
  entry_id uuid not null references public.contest_entries (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (entry_id, user_id)
);

create table public.entry_comments (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.contest_entries (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 200),
  created_at timestamptz not null default now(),
  hidden_at timestamptz
);
create index entry_comments_entry_idx on public.entry_comments (entry_id, created_at);
create index entry_comments_author_idx on public.entry_comments (author_id, created_at desc);

create table public.contest_banned_words (
  word text primary key check (word = lower(word) and char_length(word) >= 2)
);
alter table public.contest_banned_words enable row level security;
-- Empty on purpose: add words in the dashboard. Comments containing one are refused.

create table public.contest_results (
  contest_id uuid not null references public.contests (id) on delete cascade,
  rank int not null check (rank between 1 and 3),
  entry_id uuid not null references public.contest_entries (id),
  score numeric(6, 4) not null,
  vote_count int not null,
  primary key (contest_id, rank),
  unique (entry_id)
);

-- Row-level security ---------------------------------------------------------------------
-- The app reads contests and themes directly (the entry counter updates live); every
-- other table is reached only through the RPCs below.
alter table public.contest_themes enable row level security;
alter table public.contests enable row level security;
alter table public.contest_entries enable row level security;
alter table public.contest_participants enable row level security;
alter table public.entry_votes enable row level security;
alter table public.entry_reactions enable row level security;
alter table public.entry_comments enable row level security;
alter table public.contest_results enable row level security;

create policy "everyone reads themes"
  on public.contest_themes for select to authenticated using (true);
create policy "everyone reads contests"
  on public.contests for select to authenticated using (true);
create policy "everyone reads results"
  on public.contest_results for select to authenticated using (true);

grant select on public.contest_themes, public.contests, public.contest_results
  to authenticated;

-- Tick: make this week's and next week's contest, move statuses, finalize -------------------
create function public.contest_tick() returns void
language plpgsql security definer set search_path = '' as $$
declare
  i int;
  week_start timestamptz;
  key text;
  theme uuid;
  c public.contests;
begin
  -- One tick at a time; anyone who is not first just carries on.
  if not pg_try_advisory_xact_lock(7302201) then return; end if;

  for i in 0..1 loop
    week_start := public.vn_week_start(public.contest_now()) + make_interval(days => i * 7);
    key := to_char(week_start at time zone 'Asia/Ho_Chi_Minh', 'IYYY-"W"IW');
    if not exists (select 1 from public.contests where week_key = key) then
      select id into theme from public.contest_themes
      where scheduled_week is null order by ord limit 1;
      if theme is null then
        -- Every theme has been used: start again with the one used longest ago.
        select id into theme from public.contest_themes order by scheduled_week limit 1;
      end if;
      update public.contest_themes set scheduled_week = key where id = theme;
      insert into public.contests
        (week_key, theme_id, starts_at, opens_at, submit_closes_at, ends_at, max_entries)
      values (
        key, theme, week_start,
        week_start + interval '5 days',
        week_start + interval '6 days 12 hours',
        week_start + interval '7 days',
        public.cfg_int('max_entries'));
    end if;
  end loop;

  update public.contests ct
    set status = public.contest_phase(ct)
    where ct.status <> 'finalized' and ct.status <> public.contest_phase(ct);

  for c in
    select * from public.contests
    where finalized_at is null and public.contest_now() >= ends_at
    order by ends_at
  loop
    perform public.finalize_contest(c.id);
  end loop;
end;
$$;
revoke all on function public.contest_tick() from public, anon, authenticated;

-- Results: Bayesian average, top 3, prizes ----------------------------------------------------
-- score = (C * m + sum of ratings) / (C + n)
--   m = the average of every counted rating in this contest
--   n = how many counted ratings the entry has,  C = bayes_c (5)
-- A rating counts when the rater belongs to an entering group, is not rating their own
-- group, has an account at least min_account_age_days old, and has rated enough entries
-- (min_votes, or all that they were allowed to rate if there are fewer).
-- An entry needs min_votes_for_rank counted ratings to be ranked. Ties: more counted
-- ratings first, then the entry that was submitted earlier.
create function public.finalize_contest(p_contest uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  ct public.contests;
  win record;
  member_row record;
  min_votes int := public.cfg_int('min_votes');
  min_rank int := public.cfg_int('min_votes_for_rank');
  age_days int := public.cfg_int('min_account_age_days');
  bayes int := public.cfg_int('bayes_c');
  sunbit int[] := array[150, 100, 50];
  ink int[] := array[30, 20, 10];
begin
  select * into ct from public.contests where id = p_contest for update;
  if ct.id is null or ct.finalized_at is not null then return; end if;

  insert into public.contest_results (contest_id, rank, entry_id, score, vote_count)
  with entries as (
    select id, group_id, seq from public.contest_entries
    where contest_id = ct.id and status = 'accepted'
  ),
  raters as (
    -- Each person in an entering group, and how many entries they were allowed to rate.
    select u.user_id,
           least(min_votes, (
             select count(*) from entries e
             where e.group_id not in (
               select pp.group_id from public.contest_participants pp
               where pp.contest_id = ct.id and pp.user_id = u.user_id))) as needed
    from (select distinct user_id from public.contest_participants
          where contest_id = ct.id) u
  ),
  cast_votes as (
    select v.voter_id, count(*) as cast_count
    from public.entry_votes v join entries e on e.id = v.entry_id
    group by v.voter_id
  ),
  valid_raters as (
    select r.user_id from raters r
    left join cast_votes cv on cv.voter_id = r.user_id
    where coalesce(cv.cast_count, 0) >= r.needed
      and exists (
        select 1 from auth.users au
        where au.id = r.user_id
          and au.created_at <= ct.ends_at - make_interval(days => age_days))
  ),
  counted as (
    select v.entry_id, v.score
    from public.entry_votes v
    join entries e on e.id = v.entry_id
    join valid_raters vr on vr.user_id = v.voter_id
  ),
  mean as (select coalesce(avg(score), 0) as m from counted),
  stats as (
    select e.id as entry_id, e.seq, count(k.score) as n, coalesce(sum(k.score), 0) as s
    from entries e left join counted k on k.entry_id = e.id
    group by e.id, e.seq
  ),
  ranked as (
    select st.entry_id, st.n, st.seq,
           (bayes * mean.m + st.s) / (bayes + st.n) as score
    from stats st, mean
    where st.n >= min_rank
  )
  select ct.id,
         (row_number() over (order by score desc, n desc, seq asc))::int,
         entry_id, round(score::numeric, 4), n::int
  from ranked
  order by score desc, n desc, seq asc
  limit 3;

  -- Prizes for every person who was in a winning group when it entered.
  for win in
    select cr.rank, e.group_id
    from public.contest_results cr
    join public.contest_entries e on e.id = cr.entry_id
    where cr.contest_id = ct.id
  loop
    for member_row in
      select user_id from public.contest_participants
      where contest_id = ct.id and group_id = win.group_id
    loop
      perform public.touch_player(member_row.user_id);
      update public.player_state
        set balance = balance + sunbit[win.rank]
        where user_id = member_row.user_id;
      insert into public.sunbit_ledger (user_id, amount, reason)
      values (member_row.user_id, sunbit[win.rank],
              'prize:' || ct.week_key || ':' || win.rank);
      perform public.ink_change(
        member_row.user_id, ink[win.rank], 'prize:' || ct.id || ':' || win.rank);
    end loop;
  end loop;

  update public.contests
    set finalized_at = now(), status = 'finalized'
    where id = ct.id;
end;
$$;
revoke all on function public.finalize_contest(uuid) from public, anon, authenticated;

-- Internal helpers -------------------------------------------------------------------------------
create function public.is_participant(p_contest uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.contest_participants
    where contest_id = p_contest and user_id = p_user)
$$;
revoke all on function public.is_participant(uuid, uuid) from public, anon, authenticated;

create function public.entry_json(
  e public.contest_entries, p_me uuid, p_reveal boolean
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', e.id,
    'contest_id', e.contest_id,
    'seq', e.seq,
    'group_name', e.group_name,
    'width', e.width,
    'height', e.height,
    'palette', to_jsonb(pal.colors),
    'pixels', replace(encode(e.pixels, 'base64'), E'\n', ''),
    'submitted_at', e.submitted_at,
    'mine', exists (
      select 1 from public.contest_participants cp
      where cp.contest_id = e.contest_id and cp.group_id = e.group_id
        and cp.user_id = p_me),
    'my_score', (select v.score from public.entry_votes v
                 where v.entry_id = e.id and v.voter_id = p_me),
    'my_emoji', (select x.emoji from public.entry_reactions x
                 where x.entry_id = e.id and x.user_id = p_me),
    'rank', case when p_reveal then
              (select cr.rank from public.contest_results cr where cr.entry_id = e.id)
            end,
    'score', case when p_reveal then
              (select cr.score from public.contest_results cr where cr.entry_id = e.id)
            end,
    'vote_count', case when p_reveal then
              (select cr.vote_count from public.contest_results cr where cr.entry_id = e.id)
            end
  )
  from public.palettes pal where pal.id = e.palette_id
$$;
revoke all on function public.entry_json(public.contest_entries, uuid, boolean)
  from public, anon, authenticated;

-- RPCs ---------------------------------------------------------------------------------------------
-- Errors (message): not_signed_in, not_found, not_owner, not_open, not_judging,
-- already_submitted, contest_full, canvas_too_empty, group_too_small, no_canvas,
-- not_participant, own_entry, bad_score, bad_emoji, empty, too_long, too_fast,
-- too_many, blocked_word, bad_reason, too_many_reports.

-- Where things stand now, for the contest screen.
create function public.get_current_contest() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c public.contests;
  th public.contest_themes;
  prev public.contests;
  prev_th public.contest_themes;
  entry public.contest_entries;
  phase text;
  allowed int;
  voted int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.contest_tick();

  select * into c from public.contests
  where starts_at <= public.contest_now() order by starts_at desc limit 1;
  if c.id is null then return jsonb_build_object('contest', null); end if;
  select * into th from public.contest_themes where id = c.theme_id;
  phase := public.contest_phase(c);

  select e.* into entry from public.contest_entries e
  join public.contest_participants cp
    on cp.contest_id = e.contest_id and cp.group_id = e.group_id
  where e.contest_id = c.id and cp.user_id = me limit 1;

  select count(*) into allowed from public.contest_entries e
  where e.contest_id = c.id and e.status = 'accepted' and e.group_id not in (
    select group_id from public.contest_participants
    where contest_id = c.id and user_id = me);
  select count(*) into voted from public.entry_votes v
  join public.contest_entries e on e.id = v.entry_id
  where e.contest_id = c.id and v.voter_id = me;

  -- The last contest that finished, for the "last week" card.
  select * into prev from public.contests
  where finalized_at is not null and id <> c.id order by starts_at desc limit 1;
  select * into prev_th from public.contest_themes where id = prev.theme_id;

  return jsonb_build_object(
    'server_now', now(),
    'contest', jsonb_build_object(
      'id', c.id,
      'week_key', c.week_key,
      'phase', phase,
      'starts_at', c.starts_at,
      'opens_at', c.opens_at,
      'submit_closes_at', c.submit_closes_at,
      'ends_at', c.ends_at,
      'accepted_count', c.accepted_count,
      'max_entries', c.max_entries),
    'theme', jsonb_build_object(
      'category', th.category,
      'title_vi', th.title_vi, 'title_en', th.title_en,
      'brief_vi', th.brief_vi, 'brief_en', th.brief_en,
      'palette_id', th.palette_id),
    'participant', public.is_participant(c.id, me),
    'my_entry', case when entry.id is null then null else
      jsonb_build_object('id', entry.id, 'seq', entry.seq, 'group_name', entry.group_name)
      end,
    'owner_groups', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id, 'name', g.name,
        'submitted', exists (
          select 1 from public.contest_entries e
          where e.contest_id = c.id and e.group_id = g.id))
        order by g.name)
      from public.group_members m
      join public.groups g on g.id = m.group_id
      where m.user_id = me and m.role = 'owner' and g.dissolved_at is null
    ), '[]'::jsonb),
    'my_votes', voted,
    'votes_needed', least(public.cfg_int('min_votes'), allowed),
    'previous', case when prev.id is null then null else jsonb_build_object(
      'id', prev.id, 'week_key', prev.week_key,
      'title_vi', prev_th.title_vi, 'title_en', prev_th.title_en) end
  );
end;
$$;

-- The owner enters the group's canvas. p_contest null = this week's.
create function public.submit_entry(p_group uuid, p_contest uuid default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c public.contests;
  cv public.canvases;
  g public.groups;
  filled int;
  new_seq int;
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.contest_tick();
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;

  if p_contest is null then
    select * into c from public.contests
    where starts_at <= public.contest_now() order by starts_at desc limit 1;
  else
    select * into c from public.contests where id = p_contest;
  end if;
  if c.id is null then raise exception 'not_found'; end if;
  -- One submission at a time per contest: whoever gets the lock first is first.
  select * into c from public.contests where id = c.id for update;

  if public.contest_now() < c.opens_at or public.contest_now() >= c.submit_closes_at
     or c.finalized_at is not null then
    raise exception 'not_open';
  end if;
  if exists (select 1 from public.contest_entries
             where contest_id = c.id and group_id = p_group) then
    raise exception 'already_submitted';
  end if;
  if c.accepted_count >= c.max_entries then raise exception 'contest_full'; end if;

  select * into g from public.groups where id = p_group;
  if (select count(*) from public.group_members where group_id = p_group)
     < public.cfg_int('min_group_size') then
    raise exception 'group_too_small';
  end if;
  select * into cv from public.canvases where group_id = p_group and status = 'active';
  if cv.id is null then raise exception 'no_canvas'; end if;
  select count(*) into filled
  from generate_series(0, octet_length(cv.pixels) - 1) i
  where get_byte(cv.pixels, i) <> 0;
  if filled * 100 < octet_length(cv.pixels) * public.cfg_int('min_fill_percent') then
    raise exception 'canvas_too_empty';
  end if;

  new_seq := c.accepted_count + 1;
  insert into public.contest_entries
    (contest_id, group_id, submitted_by, group_name, width, height, palette_id,
     pixels, canvas_version, seq)
  values
    (c.id, p_group, me, g.name, cv.width, cv.height, cv.palette_id,
     cv.pixels, cv.version, new_seq)
  returning id into new_id;

  insert into public.contest_participants (contest_id, user_id, group_id)
  select c.id, m.user_id, p_group from public.group_members m where m.group_id = p_group;

  update public.contests
    set accepted_count = new_seq,
        status = case when new_seq >= max_entries then 'judging' else status end
    where id = c.id;

  perform public.group_post_system(p_group, me, 'entry_submitted');
  return jsonb_build_object('entry_id', new_id, 'seq', new_seq, 'contest_id', c.id);
end;
$$;

-- A page of the gallery, in the order entries were accepted.
create function public.get_gallery(
  p_contest uuid default null, p_after int default 0, p_limit int default 20
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c public.contests;
  lim int := least(greatest(coalesce(p_limit, 20), 1), 50);
  page_rows jsonb;
  last_seq int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.contest_tick();
  if p_contest is null then
    select * into c from public.contests
    where starts_at <= public.contest_now() order by starts_at desc limit 1;
  else
    select * into c from public.contests where id = p_contest;
  end if;
  if c.id is null then raise exception 'not_found'; end if;

  with page as (
    select id from public.contest_entries
    where contest_id = c.id and status = 'accepted' and seq > coalesce(p_after, 0)
    order by seq limit lim
  )
  select coalesce(jsonb_agg(public.entry_json(e, me, c.finalized_at is not null)
                            order by e.seq), '[]'::jsonb),
         max(e.seq)
  into page_rows, last_seq
  from public.contest_entries e join page on page.id = e.id;

  return jsonb_build_object(
    'contest_id', c.id,
    'phase', public.contest_phase(c),
    'entries', page_rows,
    'next_after', case when jsonb_array_length(page_rows) = lim then last_seq end
  );
end;
$$;

create function public.get_entry(p_entry uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  e public.contest_entries;
  c public.contests;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into e from public.contest_entries where id = p_entry and status = 'accepted';
  if e.id is null then raise exception 'not_found'; end if;
  select * into c from public.contests where id = e.contest_id;
  return public.entry_json(e, me, c.finalized_at is not null)
    || jsonb_build_object(
      'phase', public.contest_phase(c),
      'participant', public.is_participant(c.id, me),
      'reactions', coalesce((
        select jsonb_object_agg(emoji, n)
        from (select emoji, count(*) as n from public.entry_reactions
              where entry_id = e.id group by emoji) x), '{}'::jsonb),
      'comment_count', (select count(*) from public.entry_comments k
                        where k.entry_id = e.id and k.hidden_at is null));
end;
$$;

create function public.get_entry_comments(
  p_entry uuid, p_before timestamptz default null, p_limit int default 30
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from public.contest_entries
                 where id = p_entry and status = 'accepted') then
    raise exception 'not_found';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', k.id,
      'author_id', k.author_id,
      'author_name', coalesce(pr.display_name, pr.username, '?'),
      'body', k.body,
      'created_at', k.created_at,
      'mine', k.author_id = me) order by k.created_at desc)
    from (
      select * from public.entry_comments
      where entry_id = p_entry and hidden_at is null
        and (p_before is null or created_at < p_before)
        and (author_id = me or not public.is_blocked_between(me, author_id))
      order by created_at desc
      limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) k join public.profiles pr on pr.id = k.author_id
  ), '[]'::jsonb);
end;
$$;

-- Rate an entry 1 to 5. Only people from the entering groups, only while rating is
-- open, never their own group's entry. Can be changed until the end.
create function public.vote_entry(p_entry uuid, p_score int) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  e public.contest_entries;
  c public.contests;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_score is null or p_score not between 1 and 5 then raise exception 'bad_score'; end if;
  select * into e from public.contest_entries where id = p_entry and status = 'accepted';
  if e.id is null then raise exception 'not_found'; end if;
  select * into c from public.contests where id = e.contest_id;
  if not public.is_participant(c.id, me) then raise exception 'not_participant'; end if;
  if exists (select 1 from public.contest_participants
             where contest_id = c.id and user_id = me and group_id = e.group_id) then
    raise exception 'own_entry';
  end if;
  if public.contest_phase(c) <> 'judging' then raise exception 'not_judging'; end if;
  insert into public.entry_votes (entry_id, voter_id, score)
  values (p_entry, me, p_score)
  on conflict (entry_id, voter_id)
  do update set score = excluded.score, updated_at = now();
end;
$$;

create function public.react_entry(p_entry uuid, p_emoji text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  e public.contest_entries;
  k public.contests;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into e from public.contest_entries where id = p_entry and status = 'accepted';
  if e.id is null then raise exception 'not_found'; end if;
  select * into k from public.contests where id = e.contest_id;
  if not public.is_participant(k.id, me) then raise exception 'not_participant'; end if;
  if public.contest_phase(k) <> 'judging' then raise exception 'not_judging'; end if;
  if p_emoji is null or btrim(p_emoji) = '' then
    delete from public.entry_reactions where entry_id = p_entry and user_id = me;
    return;
  end if;
  if char_length(p_emoji) > 16 then raise exception 'bad_emoji'; end if;
  insert into public.entry_reactions (entry_id, user_id, emoji)
  values (p_entry, me, p_emoji)
  on conflict (entry_id, user_id)
  do update set emoji = excluded.emoji, created_at = now();
end;
$$;

create function public.comment_entry(p_entry uuid, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  e public.contest_entries;
  k public.contests;
  text_body text := btrim(coalesce(p_body, ''));
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if text_body = '' then raise exception 'empty'; end if;
  if char_length(text_body) > 200 then raise exception 'too_long'; end if;
  select * into e from public.contest_entries where id = p_entry and status = 'accepted';
  if e.id is null then raise exception 'not_found'; end if;
  select * into k from public.contests where id = e.contest_id;
  if not public.is_participant(k.id, me) then raise exception 'not_participant'; end if;
  if public.contest_phase(k) <> 'judging' then raise exception 'not_judging'; end if;
  if exists (select 1 from public.contest_banned_words w
             where lower(text_body) like '%' || w.word || '%') then
    raise exception 'blocked_word';
  end if;
  if exists (select 1 from public.entry_comments
             where author_id = me
               and created_at > now() - make_interval(
                 secs => public.cfg_int('comment_cooldown_seconds'))) then
    raise exception 'too_fast';
  end if;
  if (select count(*) from public.entry_comments c2
      join public.contest_entries e2 on e2.id = c2.entry_id
      where c2.author_id = me and e2.contest_id = k.id) >= public.cfg_int('max_comments') then
    raise exception 'too_many';
  end if;
  insert into public.entry_comments (entry_id, author_id, body)
  values (p_entry, me, text_body)
  returning id into new_id;
  return new_id;
end;
$$;

-- Reports -------------------------------------------------------------------------------------------
alter table public.reports
  add column target_entry uuid references public.contest_entries (id) on delete set null,
  add column target_comment uuid references public.entry_comments (id) on delete set null;

-- The old rule only knew people and posts; drop it and say it again with the new targets.
do $$
declare con record;
begin
  for con in
    select conname from pg_constraint
    where conrelid = 'public.reports'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%target_user IS NOT NULL%'
  loop
    execute format('alter table public.reports drop constraint %I', con.conname);
  end loop;
end $$;
alter table public.reports add constraint reports_has_target check (
  target_user is not null or target_post is not null
  or target_entry is not null or target_comment is not null);

create unique index reports_one_per_entry
  on public.reports (reporter_id, target_entry) where target_entry is not null;
create unique index reports_one_per_comment
  on public.reports (reporter_id, target_comment) where target_comment is not null;

-- Report an entry or a comment. Enough different people reporting hides it until
-- somebody looks at it in the dashboard.
create function public.report_gallery(
  p_entry uuid, p_comment uuid, p_reason text, p_details text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  hide_at int := public.cfg_int('report_hide_at');
  author uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if (p_entry is null) = (p_comment is null) then raise exception 'nothing_to_report'; end if;
  if p_reason not in ('spam', 'inappropriate', 'harassment', 'other') then
    raise exception 'bad_reason';
  end if;
  if char_length(coalesce(p_details, '')) > 500 then raise exception 'too_long'; end if;
  if (select count(*) from public.reports
      where reporter_id = me and created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many_reports';
  end if;

  if p_entry is not null then
    if not exists (select 1 from public.contest_entries
                   where id = p_entry and status = 'accepted') then
      raise exception 'not_found';
    end if;
    insert into public.reports (reporter_id, target_entry, reason, details)
    values (me, p_entry, p_reason, nullif(btrim(coalesce(p_details, '')), ''))
    on conflict do nothing;
    if (select count(distinct reporter_id) from public.reports
        where target_entry = p_entry) >= hide_at then
      update public.contest_entries set status = 'hidden'
        where id = p_entry and status = 'accepted';
    end if;
  else
    select author_id into author from public.entry_comments
    where id = p_comment and hidden_at is null;
    if author is null or author = me then raise exception 'not_found'; end if;
    insert into public.reports
      (reporter_id, target_user, target_comment, reason, details)
    values (me, author, p_comment, p_reason, nullif(btrim(coalesce(p_details, '')), ''))
    on conflict do nothing;
    if (select count(distinct reporter_id) from public.reports
        where target_comment = p_comment) >= hide_at then
      update public.entry_comments set hidden_at = now()
        where id = p_comment and hidden_at is null;
    end if;
  end if;
end;
$$;

-- Results of one contest (the winners), and every winner of all time. -------------------------------
create function public.get_contest_results(p_contest uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  c public.contests;
  th public.contest_themes;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.contest_tick();
  select * into c from public.contests where id = p_contest;
  if c.id is null then raise exception 'not_found'; end if;
  select * into th from public.contest_themes where id = c.theme_id;
  return jsonb_build_object(
    'contest_id', c.id,
    'week_key', c.week_key,
    'phase', public.contest_phase(c),
    'title_vi', th.title_vi, 'title_en', th.title_en,
    'entry_count', c.accepted_count,
    'winners', case when c.finalized_at is null then '[]'::jsonb else coalesce((
      select jsonb_agg(public.entry_json(e, me, true) order by cr.rank)
      from public.contest_results cr
      join public.contest_entries e on e.id = cr.entry_id
      where cr.contest_id = c.id), '[]'::jsonb) end);
end;
$$;

create function public.get_hall_of_fame(p_offset int default 0, p_limit int default 12)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  return coalesce((
    select jsonb_agg(public.entry_json(e, me, true)
             || jsonb_build_object(
                  'week_key', c.week_key,
                  'title_vi', th.title_vi, 'title_en', th.title_en)
           order by c.starts_at desc, cr.rank)
    from (
      select cr2.* from public.contest_results cr2
      join public.contests c2 on c2.id = cr2.contest_id
      order by c2.starts_at desc, cr2.rank
      offset greatest(coalesce(p_offset, 0), 0)
      limit least(greatest(coalesce(p_limit, 12), 1), 30)
    ) cr
    join public.contest_entries e on e.id = cr.entry_id
    join public.contests c on c.id = cr.contest_id
    join public.contest_themes th on th.id = c.theme_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function
  public.get_current_contest(),
  public.submit_entry(uuid, uuid),
  public.get_gallery(uuid, int, int),
  public.get_entry(uuid),
  public.get_entry_comments(uuid, timestamptz, int),
  public.vote_entry(uuid, int),
  public.react_entry(uuid, text),
  public.comment_entry(uuid, text),
  public.report_gallery(uuid, uuid, text, text),
  public.get_contest_results(uuid),
  public.get_hall_of_fame(int, int)
from public, anon;
grant execute on function
  public.get_current_contest(),
  public.submit_entry(uuid, uuid),
  public.get_gallery(uuid, int, int),
  public.get_entry(uuid),
  public.get_entry_comments(uuid, timestamptz, int),
  public.vote_entry(uuid, int),
  public.react_entry(uuid, text),
  public.comment_entry(uuid, text),
  public.report_gallery(uuid, uuid, text, text),
  public.get_contest_results(uuid),
  public.get_hall_of_fame(int, int)
to authenticated;

-- Live: the "87/100" counter and the status follow the contest row.
alter publication supabase_realtime add table public.contests;

-- Run the tick every minute when pg_cron is available. If it is not, nothing is lost:
-- every contest RPC runs the tick first.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('contest-tick', '* * * * *', 'select public.contest_tick()');
exception when others then
  raise notice 'pg_cron not available (%): the contest still advances when the app calls it', sqlerrm;
end $$;
