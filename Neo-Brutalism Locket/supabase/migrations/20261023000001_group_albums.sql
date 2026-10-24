-- Event albums: a group collects its photos of one trip or evening in one place.
--
-- An album belongs to a group and covers a time window ("Đà Lạt, 20–23/10"). A member
-- adds their OWN posts made in that window (the composer ticks the open albums by
-- default; older posts can be added from the album). Everyone in the group then sees
-- the photo in the album, also members who are not the author's friends: adding a
-- post to an album is the author's choice to show it to that group.
--
-- The feed stays friends-only: posts and post_recipients are not touched. An album
-- item keeps its own copy of the file paths, and the media bucket gets one more read
-- policy for files in an album I can see.
--
-- Clients read; every change goes through the RPCs below.
-- Errors (message): not_signed_in, not_member, not_found, not_allowed, bad_name,
-- bad_window, album_limit.

create table public.group_albums (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (ends_at > starts_at),
  check (ends_at - starts_at <= interval '31 days')
);
create index group_albums_group_idx on public.group_albums (group_id, starts_at desc);

create table public.album_items (
  album_id uuid not null references public.group_albums (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('photo', 'video')),
  -- Copied from the post (see the note at the top).
  media_path text not null,
  thumb_path text,
  original_path text,
  caption text not null default '',
  post_created_at timestamptz not null,
  added_at timestamptz not null default now(),
  primary key (album_id, post_id)
);
create index album_items_album_idx on public.album_items (album_id, post_created_at);
create index album_items_post_idx on public.album_items (post_id);
-- The storage policy looks items up by file path.
create index album_items_media_idx on public.album_items (media_path);
create index album_items_thumb_idx on public.album_items (thumb_path)
  where thumb_path is not null;
create index album_items_original_idx on public.album_items (original_path)
  where original_path is not null;

-- Helpers used by policies -------------------------------------------------------------

-- May I see this album? A member of its live group, and the album not deleted.
create function public.album_visible(p_album uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.group_albums a
    join public.group_members m on m.group_id = a.group_id
    join public.groups g on g.id = a.group_id
    where a.id = p_album and a.deleted_at is null
      and m.user_id = auth.uid() and g.dissolved_at is null
  )
$$;

-- May I see this item? The album, a post that still exists, and nobody blocked.
create function public.album_item_visible(
  p_album uuid, p_post uuid, p_author uuid
) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.album_visible(p_album)
    and exists (
      select 1 from public.posts p where p.id = p_post and p.deleted_at is null
    )
    and (p_author = auth.uid()
         or not public.is_blocked_between(auth.uid(), p_author))
$$;

revoke all on function public.album_visible(uuid) from public, anon;
revoke all on function public.album_item_visible(uuid, uuid, uuid) from public, anon;
grant execute on function public.album_visible(uuid) to authenticated;
grant execute on function public.album_item_visible(uuid, uuid, uuid) to authenticated;

alter table public.group_albums enable row level security;
alter table public.album_items enable row level security;

create policy "members read their groups' albums"
  on public.group_albums for select to authenticated
  using (deleted_at is null and public.is_group_member(group_id));

create policy "members read album items"
  on public.album_items for select to authenticated
  using (public.album_item_visible(album_id, post_id, author_id));

grant select on public.group_albums, public.album_items to authenticated;

-- Members of an album's group may read the files of the items they can see. Policies
-- add up, so the existing authors-and-recipients policy stays as it is.
create policy "album members read album media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'media'
    and exists (
      select 1 from public.album_items i
      where (i.media_path = name or i.thumb_path = name or i.original_path = name)
        and public.album_item_visible(i.album_id, i.post_id, i.author_id)
    )
  );

-- RPCs -----------------------------------------------------------------------------------

-- Any member may start an album. [p_starts, p_ends) is at most 31 days; at most 20
-- live albums per group.
create function public.create_album(
  p_group uuid, p_name text, p_starts timestamptz, p_ends timestamptz
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  clean text := btrim(coalesce(p_name, ''));
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.is_group_member(p_group) then raise exception 'not_member'; end if;
  if char_length(clean) not between 1 and 40 then raise exception 'bad_name'; end if;
  if p_starts is null or p_ends is null or p_ends <= p_starts
     or p_ends - p_starts > interval '31 days' then
    raise exception 'bad_window';
  end if;
  -- Serialise album creation per group so the limit holds.
  perform 1 from public.groups where id = p_group for update;
  if (select count(*) from public.group_albums
      where group_id = p_group and deleted_at is null) >= 20 then
    raise exception 'album_limit';
  end if;
  insert into public.group_albums (group_id, name, starts_at, ends_at, created_by)
  values (p_group, clean, p_starts, p_ends, me)
  returning id into new_id;
  return new_id;
end;
$$;

-- Who started the album, or the group's owner.
create function public.delete_album(p_album uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  a public.group_albums;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into a from public.group_albums where id = p_album and deleted_at is null;
  if a.id is null or not public.is_group_member(a.group_id) then
    raise exception 'not_found';
  end if;
  if a.created_by is distinct from me and not public.group_is_owner(a.group_id, me) then
    raise exception 'not_allowed';
  end if;
  update public.group_albums set deleted_at = now() where id = p_album;
end;
$$;

-- Adds one of MY posts to an album of a group I am in. True when it is in the album
-- now (also when it already was); false when it may not go in: not my post, deleted,
-- made outside the window, album gone or full. A post that waited in the outbox is
-- created on the server late, so the window gets a day of grace at its end.
create function public.add_to_album(p_album uuid, p_post uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  a public.group_albums;
  p public.posts;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into a from public.group_albums where id = p_album and deleted_at is null;
  if a.id is null or not public.is_group_member(a.group_id) then return false; end if;
  select * into p from public.posts
  where id = p_post and author_id = me and deleted_at is null;
  if p.id is null then return false; end if;
  if p.created_at < a.starts_at or p.created_at >= a.ends_at + interval '1 day' then
    return false;
  end if;
  if exists (select 1 from public.album_items
             where album_id = p_album and post_id = p_post) then
    return true;
  end if;
  if (select count(*) from public.album_items where album_id = p_album) >= 1000 then
    return false;
  end if;
  insert into public.album_items
    (album_id, post_id, author_id, kind, media_path, thumb_path, original_path,
     caption, post_created_at)
  values
    (p_album, p_post, me, p.kind, p.media_path, p.thumb_path, p.original_path,
     p.caption, p.created_at)
  on conflict do nothing;
  return true;
end;
$$;

-- The author takes their photo out; the album's starter or the group's owner may
-- take out anyone's.
create function public.remove_from_album(p_album uuid, p_post uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  a public.group_albums;
  author uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into a from public.group_albums where id = p_album and deleted_at is null;
  if a.id is null or not public.is_group_member(a.group_id) then
    raise exception 'not_found';
  end if;
  select author_id into author from public.album_items
  where album_id = p_album and post_id = p_post;
  if author is null then return; end if;
  if author <> me and a.created_by is distinct from me
     and not public.group_is_owner(a.group_id, me) then
    raise exception 'not_allowed';
  end if;
  delete from public.album_items where album_id = p_album and post_id = p_post;
end;
$$;

revoke all on function
  public.create_album(uuid, text, timestamptz, timestamptz),
  public.delete_album(uuid),
  public.add_to_album(uuid, uuid),
  public.remove_from_album(uuid, uuid)
from public, anon;
grant execute on function
  public.create_album(uuid, text, timestamptz, timestamptz),
  public.delete_album(uuid),
  public.add_to_album(uuid, uuid),
  public.remove_from_album(uuid, uuid)
to authenticated;
