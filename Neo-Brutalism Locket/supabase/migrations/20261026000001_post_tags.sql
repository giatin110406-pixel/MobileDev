-- Post tags, as on Facebook: the author tags the friends they were WITH ("with Lan"), whether or not
-- they are in the picture (a plate of food shared with Lan is tagged "with Lan" too).
--
--  * The post shows who it is with, and photo search uses the tags to find "with Lan".
--  * Tagging a friend also sends them the post (they become a recipient, with the usual push), so
--    nobody is tagged on something they cannot see.
--  * The tagged person can take their own name off (remove_my_tag). The post stays; the author
--    cannot put the name back.
--
-- A tag is as private as the post: it is read by whoever can read the post (the author and the
-- recipients, through the existing posts policy) and goes away with it. Only the author writes
-- tags, only for their own friends, through set_post_tags().

create table public.post_tags (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (post_id, user_id)
);
create index post_tags_user_idx on public.post_tags (user_id, post_id);

-- Who took their name off which post. Not readable or writable by clients: only the two functions
-- below touch it.
create table public.post_tag_removals (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (post_id, user_id)
);

alter table public.post_tags enable row level security;
alter table public.post_tag_removals enable row level security;

-- The subquery runs under the posts policy, so a post I cannot see shows no tags either.
create policy "whoever can read the post reads its tags"
  on public.post_tags for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_tags.post_id));

grant select on public.post_tags to authenticated;

-- Replaces the tags of one of my posts with [p_tagged]: only my friends (not blocked), and not
-- anyone who took their name off this post. The tagged friends also become recipients. Calling it
-- again with the same list changes nothing, so a retry after a dropped connection is safe.
-- Errors (message): not_signed_in, not_found, too_many_tags.
create function public.set_post_tags(p_post uuid, p_tagged uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (
    select 1 from public.posts
    where id = p_post and author_id = me and deleted_at is null
  ) then
    raise exception 'not_found';
  end if;
  if coalesce(cardinality(p_tagged), 0) > 20 then raise exception 'too_many_tags'; end if;

  delete from public.post_tags where post_id = p_post;
  insert into public.post_tags (post_id, user_id)
  select distinct p_post, f.other_id
  from (
    select case when user_a = me then user_b else user_a end as other_id
    from public.friendships
    where me in (user_a, user_b)
  ) f
  where f.other_id = any (coalesce(p_tagged, '{}'::uuid[]))
    and not public.is_blocked_between(me, f.other_id)
    and not exists (
      select 1 from public.post_tag_removals r
      where r.post_id = p_post and r.user_id = f.other_id
    );

  -- Whoever is tagged gets the post (and its push, for those who did not have it yet).
  insert into public.post_recipients (post_id, user_id)
  select t.post_id, t.user_id from public.post_tags t where t.post_id = p_post
  on conflict do nothing;
end;
$$;
revoke all on function public.set_post_tags(uuid, uuid[]) from public, anon;
grant execute on function public.set_post_tags(uuid, uuid[]) to authenticated;

-- The tagged person takes their own name off a post. The post stays for everyone it was sent to.
create function public.remove_my_tag(p_post uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  delete from public.post_tags where post_id = p_post and user_id = me;
  if found then
    insert into public.post_tag_removals (post_id, user_id) values (p_post, me)
    on conflict do nothing;
  end if;
end;
$$;
revoke all on function public.remove_my_tag(uuid) from public, anon;
grant execute on function public.remove_my_tag(uuid) to authenticated;
