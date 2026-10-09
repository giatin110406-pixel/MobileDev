-- Family friendly: one list of words the app refuses, in Vietnamese and English.
--
-- A word is refused only as a WHOLE word (or phrase): "class" and "du lich" pass, "ass"
-- on its own does not. Entries are of two kinds:
--   plain = false  matched as typed (with Vietnamese accents), for words that would
--                  collide with ordinary words once accents are dropped
--                  ("lồn" is refused; "lon bia" (a can of beer) is fine).
--   plain = true   matched after removing accents from the text, for English words and
--                  for Vietnamese typed without accents ("dit me", "vcl").
--
-- It protects: contest comments, the group chat, and group names and rules (a group's
-- name is shown to everybody in the Gallery). It does not look at friends' direct
-- messages. It cannot catch every disguise (f.u.c.k, letters swapped for numbers);
-- reports and the automatic hiding at 3 reports back it up. To add or remove a word,
-- edit the table contest_banned_words in the dashboard (lowercase, one row per word).

create extension if not exists unaccent with schema extensions;

alter table public.contest_banned_words
  add column plain boolean not null default false;

insert into public.contest_banned_words (word, plain) values
  -- Vietnamese, with accents
  ('địt', false),
  ('địt mẹ', false),
  ('địt con mẹ', false),
  ('đụ', false),
  ('đụ má', false),
  ('đụ mẹ', false),
  ('đéo', false),
  ('lồn', false),
  ('cặc', false),
  ('buồi', false),
  ('đĩ', false),
  ('cứt', false),
  ('đồ chó', false),
  ('óc chó', false),
  ('súc vật', false),
  ('mất dạy', false),
  ('khốn nạn', false),
  ('đồ khốn', false),
  ('đồ ngu', false),
  ('thằng ngu', false),
  ('con điên', false),
  ('đi chết', false),
  ('khiêu dâm', false),
  ('làm tình', false),
  ('ảnh nóng', false),
  -- Vietnamese without accents (typed on a phone without a Vietnamese keyboard)
  ('dit me', true),
  ('dit con me', true),
  ('du ma', true),
  ('du me', true),
  ('dmm', true),
  ('dcm', true),
  ('dkm', true),
  ('vcl', true),
  ('vkl', true),
  -- English
  ('fuck', true),
  ('fucks', true),
  ('fucked', true),
  ('fucking', true),
  ('fucker', true),
  ('fuckers', true),
  ('motherfucker', true),
  ('shit', true),
  ('shits', true),
  ('shitty', true),
  ('bullshit', true),
  ('bitch', true),
  ('bitches', true),
  ('asshole', true),
  ('assholes', true),
  ('bastard', true),
  ('bastards', true),
  ('dick', true),
  ('dicks', true),
  ('dickhead', true),
  ('cock', true),
  ('cocks', true),
  ('pussy', true),
  ('pussies', true),
  ('cunt', true),
  ('cunts', true),
  ('whore', true),
  ('whores', true),
  ('slut', true),
  ('sluts', true),
  ('porn', true),
  ('porno', true),
  ('nude', true),
  ('nudes', true),
  ('sex', true),
  ('sexy', true),
  ('sexting', true),
  ('blowjob', true),
  ('handjob', true),
  ('cum', true),
  ('boob', true),
  ('boobs', true),
  ('tits', true),
  ('titties', true),
  ('penis', true),
  ('vagina', true),
  ('anal', true),
  ('rape', true),
  ('raped', true),
  ('rapist', true),
  ('nigger', true),
  ('nigga', true),
  ('faggot', true),
  ('fag', true),
  ('retard', true),
  ('retarded', true),
  ('kys', true),
  ('kill yourself', true)
on conflict (word) do nothing;

-- Does the text contain a refused word?
create function public.contains_banned_word(p_text text) returns boolean
language sql stable security definer set search_path = '' as $$
  with t as (
    select ' ' || regexp_replace(lower(coalesce(p_text, '')), '\s+', ' ', 'g') || ' ' as accented,
           ' ' || regexp_replace(extensions.unaccent(lower(coalesce(p_text, ''))), '\s+', ' ', 'g') || ' ' as plain
  )
  select exists (
    select 1 from public.contest_banned_words w, t
    where (case when w.plain then t.plain else t.accented end)
          ~ ('[^[:alnum:]]' || w.word || '[^[:alnum:]]')
  )
$$;
revoke all on function public.contains_banned_word(text) from public, anon, authenticated;

-- The places that check it ----------------------------------------------------------------
create or replace function public.create_group(
  p_name text,
  p_rules text default '',
  p_max_members int default 12
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  gid uuid;
  clean text := btrim(coalesce(p_name, ''));
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if char_length(clean) not between 1 and 40 then raise exception 'bad_name'; end if;
  if char_length(coalesce(p_rules, '')) > 500 then raise exception 'too_long'; end if;
  if public.contains_banned_word(clean || ' ' || coalesce(p_rules, '')) then raise exception 'blocked_word'; end if;
  if p_max_members not between 2 and 12 then raise exception 'bad_size'; end if;
  if (select count(*) from public.group_members m
      join public.groups g on g.id = m.group_id
      where m.user_id = me and m.role = 'owner' and g.dissolved_at is null) >= 3
     or (select count(*) from public.group_members m
         join public.groups g on g.id = m.group_id
         where m.user_id = me and g.dissolved_at is null) >= 5 then
    raise exception 'group_limit';
  end if;

  insert into public.groups (name, rules, max_members)
  values (clean, coalesce(p_rules, ''), p_max_members)
  returning id into gid;
  insert into public.group_members (group_id, user_id, role)
  values (gid, me, 'owner');
  return gid;
end;
$$;

create or replace function public.update_group(
  p_group uuid,
  p_name text,
  p_rules text,
  p_max_members int,
  p_avatar_path text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  clean text := btrim(coalesce(p_name, ''));
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if char_length(clean) not between 1 and 40 then raise exception 'bad_name'; end if;
  if char_length(coalesce(p_rules, '')) > 500 then raise exception 'too_long'; end if;
  if public.contains_banned_word(clean || ' ' || coalesce(p_rules, '')) then raise exception 'blocked_word'; end if;
  if p_max_members not between 2 and 12 then raise exception 'bad_size'; end if;
  -- Cannot shrink below who is already in.
  if p_max_members < (select count(*) from public.group_members
                      where group_id = p_group) then
    raise exception 'bad_size';
  end if;
  if p_avatar_path is not null and p_avatar_path not like (me::text || '/%') then
    raise exception 'bad_path';
  end if;
  update public.groups
    set name = clean,
        rules = coalesce(p_rules, ''),
        max_members = p_max_members,
        avatar_path = coalesce(p_avatar_path, avatar_path)
    where id = p_group;
end;
$$;

create or replace function public.send_group_message(p_group uuid, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  text_body text := btrim(coalesce(p_body, ''));
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if text_body = '' then raise exception 'empty'; end if;
  if char_length(text_body) > 500 then raise exception 'too_long'; end if;
  if public.contains_banned_word(text_body) then raise exception 'blocked_word'; end if;
  if not public.is_group_member(p_group) then raise exception 'not_member'; end if;
  insert into public.group_messages (group_id, sender_id, kind, body)
  values (p_group, me, 'text', text_body)
  returning id into new_id;
  return new_id;
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
  if public.contest_phase(k) <> 'judging' then raise exception 'not_judging'; end if;
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
