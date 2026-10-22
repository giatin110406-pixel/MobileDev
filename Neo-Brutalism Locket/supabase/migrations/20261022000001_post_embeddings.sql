-- Photo search (archive-ai-search-plan.md, phase B): every post can carry a vector of what its
-- photo shows, made on the author's phone by the same image model as the daily quest
-- (MobileCLIP2-S0): 512 numbers as little-endian float16 = 1024 bytes.
--
-- The vector is a column of the post, so it is exactly as private as the photo: readable by the
-- author and the recipients through the existing posts policy, hidden when the post is deleted.
-- It cannot be turned back into the photo, but it does say roughly what is in it.
--
-- Clients send and receive it as base64 text (PostgREST and the Dart client handle text more
-- simply than bytea).

alter table public.posts
  add column embedding bytea
    check (embedding is null or octet_length(embedding) = 1024),
  -- when the vector was set: at posting, or later by the author's backfill
  add column embedded_at timestamptz;

create index posts_embedded_at_idx
  on public.posts (embedded_at, id) where embedding is not null;

-- base64 text -> the 1024 bytes, or the error code the app shows.
create function public.decode_post_embedding(p_embedding text) returns bytea
language plpgsql immutable set search_path = '' as $$
declare
  v bytea;
begin
  if p_embedding is null then return null; end if;
  begin
    v := decode(p_embedding, 'base64');
  exception when others then
    raise exception 'bad_embedding';
  end;
  if octet_length(v) <> 1024 then raise exception 'bad_embedding'; end if;
  return v;
end;
$$;
revoke all on function public.decode_post_embedding(text) from public, anon;

-- create_post gains p_embedding (last, optional). The old signature goes so that PostgREST never
-- has two overloads to choose from. Everything else is unchanged from 20261015000001.
drop function public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[], text);

create function public.create_post(
  p_id uuid,
  p_kind text,
  p_media_path text,
  p_thumb_path text,
  p_caption text,
  p_style text,
  p_quest_id text,
  p_overlay jsonb,
  p_recipients uuid[] default null,
  p_original_path text default null,
  p_embedding text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  v_embedding bytea;
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
     or (p_thumb_path is not null and p_thumb_path not like (me::text || '/%'))
     or (p_original_path is not null and p_original_path not like (me::text || '/%')) then
    raise exception 'bad_path';
  end if;
  if char_length(coalesce(p_caption, '')) > 80 then
    raise exception 'caption_too_long';
  end if;
  v_embedding := public.decode_post_embedding(p_embedding);

  insert into public.posts
    (id, author_id, kind, media_path, thumb_path, original_path, caption, style,
     quest_id, overlay, embedding, embedded_at)
  values
    (p_id, me, p_kind, p_media_path, p_thumb_path, p_original_path,
     coalesce(p_caption, ''), p_style, p_quest_id, p_overlay,
     v_embedding, case when v_embedding is null then null else now() end);

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
  public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[], text, text)
from public, anon;
grant execute on function
  public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[], text, text)
to authenticated;

-- The author's phone fills in the vector of an older post (backfill). Only the author, only a
-- post that still exists.
create function public.set_post_embedding(p_id uuid, p_embedding text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  v bytea := public.decode_post_embedding(p_embedding);
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if v is null then raise exception 'bad_embedding'; end if;
  update public.posts set embedding = v, embedded_at = now()
  where id = p_id and author_id = me and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
end;
$$;
revoke all on function public.set_post_embedding(uuid, text) from public, anon;
grant execute on function public.set_post_embedding(uuid, text) to authenticated;

-- Vectors of the posts the caller may see (the posts policy decides: security invoker), oldest
-- first by when the vector was set, so a phone can keep a local copy and ask only for what is
-- new: pass the last (embedded_at, id) it got. At most 1000 per call.
create function public.post_embeddings(
  p_after timestamptz default null,
  p_after_id uuid default null,
  p_limit int default 500
) returns table (id uuid, embedded_at timestamptz, embedding text)
language sql stable security invoker set search_path = '' as $$
  select p.id, p.embedded_at, encode(p.embedding, 'base64')
  from public.posts p
  where p.embedding is not null
    and (p_after is null
         or (p.embedded_at, p.id) > (p_after, coalesce(p_after_id, '00000000-0000-0000-0000-000000000000'::uuid)))
  order by p.embedded_at, p.id
  limit least(greatest(coalesce(p_limit, 500), 1), 1000);
$$;
revoke all on function public.post_embeddings(timestamptz, uuid, int) from public, anon;
grant execute on function public.post_embeddings(timestamptz, uuid, int) to authenticated;

-- Ids of the posts with a vector the caller may still see: the phone drops from its copy any id
-- that is no longer here (deleted post, removed friend, block).
create function public.visible_embedding_ids() returns setof uuid
language sql stable security invoker set search_path = '' as $$
  select p.id from public.posts p where p.embedding is not null;
$$;
revoke all on function public.visible_embedding_ids() from public, anon;
grant execute on function public.visible_embedding_ids() to authenticated;
