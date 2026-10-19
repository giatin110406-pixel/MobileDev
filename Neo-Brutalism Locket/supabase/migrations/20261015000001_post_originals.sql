-- Posts keep the original shot beside the styled one, so anyone who can see a post
-- can drag across the picture and compare before and after.
--
-- original_path: path in the private `media` bucket (<author_id>/<post_id>_orig.jpg).
-- Null for videos, for posts with no style, and for posts made before this change.
alter table public.posts add column original_path text;

-- create_post gains p_original_path (last, optional). The old signature goes so
-- that PostgREST never has two overloads to choose from.
drop function public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[]);

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
  p_original_path text default null
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
     or (p_thumb_path is not null and p_thumb_path not like (me::text || '/%'))
     or (p_original_path is not null and p_original_path not like (me::text || '/%')) then
    raise exception 'bad_path';
  end if;
  if char_length(coalesce(p_caption, '')) > 80 then
    raise exception 'caption_too_long';
  end if;

  insert into public.posts
    (id, author_id, kind, media_path, thumb_path, original_path, caption, style,
     quest_id, overlay)
  values
    (p_id, me, p_kind, p_media_path, p_thumb_path, p_original_path,
     coalesce(p_caption, ''), p_style, p_quest_id, p_overlay);

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
  public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[], text)
from public, anon;
grant execute on function
  public.create_post(uuid, text, text, text, text, text, text, jsonb, uuid[], text)
to authenticated;

-- Recipients may read the original file too.
drop policy "authors and recipients read media" on storage.objects;
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
          and (p.media_path = name or p.thumb_path = name
               or p.original_path = name)
      )
    )
  );
