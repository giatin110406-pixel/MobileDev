-- Posts: a photo (later: video) one person sends to some or all of their friends.
-- Clients READ posts and recipients; creating goes through create_post().

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null default 'photo' check (kind in ('photo', 'video')),
  -- Paths in the private `media` bucket: <author_id>/<post_id>.<ext>
  media_path text not null,
  thumb_path text,
  caption text not null default '' check (char_length(caption) <= 80),
  style text check (style in ('none', 'pixel8bit', 'vanGogh')),
  quest_id text,
  -- Free-form labels drawn on the photo, e.g. {"time": "...", "place": "..."}.
  overlay jsonb,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index posts_author_idx on public.posts (author_id, created_at desc);

create table public.post_recipients (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index post_recipients_user_idx
  on public.post_recipients (user_id, created_at desc);

-- Lets a policy on post_recipients ask "am I the author?" without the two
-- tables' policies calling each other forever.
create function public.is_post_author(p_post uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.posts where id = p_post and author_id = auth.uid()
  )
$$;
revoke all on function public.is_post_author(uuid) from public, anon;
grant execute on function public.is_post_author(uuid) to authenticated;

alter table public.posts enable row level security;
alter table public.post_recipients enable row level security;

create policy "authors and recipients read posts"
  on public.posts for select to authenticated
  using (
    deleted_at is null
    and (
      author_id = (select auth.uid())
      or exists (
        select 1 from public.post_recipients r
        where r.post_id = posts.id and r.user_id = (select auth.uid())
      )
    )
  );

create policy "recipients and authors read recipient rows"
  on public.post_recipients for select to authenticated
  using (user_id = (select auth.uid()) or public.is_post_author(post_id));

grant select on public.posts, public.post_recipients to authenticated;

-- RPC: create a post ---------------------------------------------------------------
-- Upload the file(s) first (path starts with your user id), then call this with a
-- client-made id. Calling again with the same id is a no-op, so a retry after a
-- dropped connection never sends twice.
-- p_recipients: null = all current friends; otherwise only those of them listed.
-- Errors (message): not_signed_in, conflict, bad_kind, bad_path, caption_too_long.
create function public.create_post(
  p_id uuid,
  p_kind text,
  p_media_path text,
  p_thumb_path text,
  p_caption text,
  p_style text,
  p_quest_id text,
  p_overlay jsonb,
  p_recipients uuid[] default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;

  if exists (select 1 from public.posts where id = p_id) then
    if exists (select 1 from public.posts where id = p_id and author_id = me) then
      return p_id;
    end if;
    raise exception 'conflict';
  end if;

  if p_kind not in ('photo', 'video') then raise exception 'bad_kind'; end if;
  if p_media_path not like (me::text || '/%')
     or (p_thumb_path is not null and p_thumb_path not like (me::text || '/%')) then
    raise exception 'bad_path';
  end if;
  if char_length(coalesce(p_caption, '')) > 80 then
    raise exception 'caption_too_long';
  end if;

  insert into public.posts
    (id, author_id, kind, media_path, thumb_path, caption, style, quest_id, overlay)
  values
    (p_id, me, p_kind, p_media_path, p_thumb_path, coalesce(p_caption, ''),
     p_style, p_quest_id, p_overlay);

  insert into public.post_recipients (post_id, user_id)
  select p_id, f.other_id
  from (
    select case when user_a = me then user_b else user_a end as other_id
    from public.friendships
    where me in (user_a, user_b)
  ) f
  where (p_recipients is null or f.other_id = any (p_recipients))
    and not public.is_blocked_between(me, f.other_id);

  return p_id;
end;
$$;
revoke all on function
  public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[])
from public, anon;
grant execute on function
  public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[])
to authenticated;

-- Media bucket: media/<author_id>/<file> --------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media', 'media', false, 10485760,
  array['image/jpeg', 'image/png', 'video/mp4']
)
on conflict (id) do nothing;

create policy "authors upload their media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "authors delete their media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Authors see their own files; recipients see files of posts sent to them.
create policy "authors and recipients read media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'media'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1
        from public.post_recipients r
        join public.posts p on p.id = r.post_id
        where r.user_id = (select auth.uid())
          and p.deleted_at is null
          and (p.media_path = name or p.thumb_path = name)
      )
    )
  );

-- New posts show up on friends' phones without a refresh (RLS still applies).
alter publication supabase_realtime add table public.post_recipients;
