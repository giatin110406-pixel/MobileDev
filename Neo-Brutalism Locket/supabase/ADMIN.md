# Running the contest: admin cheat sheet

There is no admin screen on purpose: the Supabase Dashboard (SQL editor, or
`npx supabase db query --linked "<sql>"`) is enough for one person. Everything below
is plain SQL for the project owner. The app and its users cannot run any of it.

Times are stored in UTC. A contest week runs Monday 00:00 to the next Monday 00:00
**Vietnam time (UTC+7)**: submissions open Saturday 00:00, rating starts Sunday 12:00
(or when 100 entries are in), the result is final at Sunday 23:59:59.

## Themes

```sql
-- What is coming and what was used (scheduled_week is null = waiting its turn)
select ord, category, title_en, scheduled_week from public.contest_themes order by ord;

-- Add a theme (use things and moments, never characters or logos that belong to somebody)
insert into public.contest_themes
  (ord, category, title_vi, title_en, brief_vi, brief_en, palette_id)
values (17, '8bit', 'Máy nghe nhạc băng', 'The Cassette Player',
        'Chiếc máy nghe nhạc băng cassette.', 'A cassette player.', 'eightbit');

-- Choose the theme of a week that has not started yet (swap with whatever it had)
update public.contest_themes set scheduled_week = null
  where scheduled_week = '2026-W45';
update public.contest_themes set scheduled_week = '2026-W45' where ord = 17;
update public.contests set theme_id = (select id from public.contest_themes where ord = 17)
  where week_key = '2026-W45' and starts_at > now();
```

The next unused theme is picked automatically when a week is created (two weeks ahead).
When every theme has been used, the one used longest ago comes back.

## This week

```sql
select week_key, status, accepted_count, opens_at, submit_closes_at, ends_at
from public.contests order by starts_at desc limit 5;

-- Entries in the order they were accepted
select seq, group_name, status, submitted_at
from public.contest_entries where contest_id = (
  select id from public.contests order by starts_at desc limit 1) order by seq;
```

## Moderation

```sql
-- Open reports, newest first (what was reported, by how many people)
select r.created_at, r.reason, r.details,
       (select count(distinct reporter_id) from public.reports x
         where x.target_entry = r.target_entry) as entry_reporters,
       r.target_entry, r.target_comment
from public.reports r
where r.target_entry is not null or r.target_comment is not null
order by r.created_at desc limit 50;

-- Take an entry out of the Gallery and the shop (it can be put back: status = 'accepted')
update public.contest_entries set status = 'hidden' where id = '<entry id>';
-- Disqualify it for good (it can no longer win)
update public.contest_entries set status = 'disqualified' where id = '<entry id>';

-- Hide or restore a comment
update public.entry_comments set hidden_at = now() where id = '<comment id>';
update public.entry_comments set hidden_at = null where id = '<comment id>';
```

Three different people reporting an entry or a comment hides it by itself; look at it
here and either restore it or disqualify it. Hiding an entry that is already a result
does not change the result (it was final); it only stops its shop sales.

## Words that are refused

```sql
select word, plain from public.contest_banned_words order by word;

-- Add (lowercase). plain = true: matched after removing accents (English words, or
-- Vietnamese typed without accents). plain = false: matched as typed.
insert into public.contest_banned_words (word, plain) values ('some word', true)
  on conflict (word) do nothing;

delete from public.contest_banned_words where word = 'some word';

-- Try the filter
select public.contains_banned_word('some text');
```

Words are matched as whole words only ("class" is fine even though it contains "ass").

## Numbers you can change

```sql
select * from public.contest_config order by key;
update public.contest_config set value = '8' where key = 'min_votes';
```

`max_entries` (100), `min_group_size` (2), `min_fill_percent` (10, the part of the
canvas that must be painted), `min_votes` (10, how many entries a rater must rate for
their ratings to count), `min_votes_for_rank` (3), `min_account_age_days` (7),
`bayes_c` (5), `comment_cooldown_seconds` (15), `max_comments` (30 per contest),
`report_hide_at` (3). A change applies to contests that have not been finalized yet;
`max_entries` is copied into a contest when it is created.

## Results and the shop

```sql
select c.week_key, cr.rank, e.group_name, cr.score, cr.vote_count
from public.contest_results cr
join public.contests c on c.id = cr.contest_id
join public.contest_entries e on e.id = cr.entry_id
order by c.starts_at desc, cr.rank;

-- The winning paintings on sale, and how many were sold
select id, title, price, sold, stock from public.shop_items
where source_entry_id is not null order by sold desc;

-- Stop selling one (people who bought it keep it)
update public.shop_items set stock = sold where id = 'contest_<entry id>';
```

Prizes (150 / 100 / 50 Sunbit and 30 / 20 / 10 Ink per person of a winning group) are
paid once, when the contest is finalized. Each winner also gets a free copy of their
painting's banner, and 20% of each sale is shared by the group that painted it.

## If a week did not finalize

The contest finalizes itself the first time anything asks about it after Sunday
23:59:59 (and once a minute through pg_cron). To force it:

```sql
select public.contest_tick();
```

It is safe to run again: nothing is paid twice.

## Cleaning up after the e2e scripts

```sql
delete from public.contests where week_key like 'E2E-%';
delete from public.groups where name like 'E2E %';
```
