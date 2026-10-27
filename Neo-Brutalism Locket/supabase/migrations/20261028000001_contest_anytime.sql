-- The time rules of the weekly contest can be switched off (for now they are off).
--
-- Normally a group's owner can submit only from Saturday 00:00, and the entries can be
-- rated, reacted to and commented on only during judging (from 100 entries or Sunday
-- 12:00). With `anytime` = 1 in contest_config:
--   * submitting works any time in the week, until it ends (Monday 00:00);
--   * rating, reactions and comments work any time in the week too.
-- Everything else stays: one entry per group, 100 entries at most, the canvas
-- checks, who may rate (members of groups that entered, not their own entry), the
-- judging rules, and the results and prizes when the week ends.
--
-- To bring the time rules back:
--   update public.contest_config set value = '0' where key = 'anytime';

insert into public.contest_config (key, value) values ('anytime', '1')
  on conflict (key) do update set value = excluded.value;

-- Are the time rules off?
create or replace function public.contest_anytime() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select value from public.contest_config where key = 'anytime'), '0') = '1'
$$;
revoke all on function public.contest_anytime() from public, anon, authenticated;

-- May the entries of [c] be rated, reacted to and commented on now?
create or replace function public.contest_rating_open(c public.contests) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.contest_phase(c) = 'judging'
      or (public.contest_anytime() and public.contest_phase(c) in ('upcoming', 'open'))
$$;
revoke all on function public.contest_rating_open(public.contests)
  from public, anon, authenticated;

-- Submitting ------------------------------------------------------------------------
create or replace function public.submit_entry(p_group uuid, p_contest uuid default null)
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

  -- With the time rules off, any time before the week ends.
  if c.finalized_at is not null or public.contest_now() >= c.ends_at
     or (not public.contest_anytime()
         and (public.contest_now() < c.opens_at
              or public.contest_now() >= c.submit_closes_at)) then
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

-- Rating, reactions and comments ------------------------------------------------------
create or replace function public.vote_entry(p_entry uuid, p_score int) returns void
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
  if not public.contest_rating_open(c) then raise exception 'not_judging'; end if;
  insert into public.entry_votes (entry_id, voter_id, score)
  values (p_entry, me, p_score)
  on conflict (entry_id, voter_id)
  do update set score = excluded.score, updated_at = now();
end;
$$;

create or replace function public.react_entry(p_entry uuid, p_emoji text) returns void
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
  if not public.contest_rating_open(k) then raise exception 'not_judging'; end if;
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

create or replace function public.comment_entry(p_entry uuid, p_body text) returns uuid
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
  if not public.contest_rating_open(k) then raise exception 'not_judging'; end if;
  if public.contains_banned_word(text_body) then raise exception 'blocked_word'; end if;
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

-- What the app is told ---------------------------------------------------------------
create or replace function public.get_current_contest() returns jsonb
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
      'max_entries', c.max_entries,
      'anytime', public.contest_anytime()),
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

create or replace function public.get_entry(p_entry uuid) returns jsonb
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
      'rating_open', public.contest_rating_open(c),
      'participant', public.is_participant(c.id, me),
      'reactions', coalesce((
        select jsonb_object_agg(emoji, n)
        from (select emoji, count(*) as n from public.entry_reactions
              where entry_id = e.id group by emoji) x), '{}'::jsonb),
      'comment_count', (select count(*) from public.entry_comments k
                        where k.entry_id = e.id and k.hidden_at is null));
end;
$$;
