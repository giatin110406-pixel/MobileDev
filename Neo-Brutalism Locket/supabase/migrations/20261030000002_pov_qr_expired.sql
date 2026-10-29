-- A code that ran out says "expired" however it was found out.
--
-- The calls close what has run out of time before they look (pov_sweep), so a code that
-- was found out to be old could read as "not found". Now an old code is "expired" whether
-- or not it was already closed.

create or replace function public.peek_pov_code(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  s public.pov_sessions;
  who public.profiles;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into s from public.pov_sessions where code = btrim(coalesce(p_code, ''));
  if s.id is null then raise exception 'not_found'; end if;
  -- A code that ran out may already have been closed by another call: still "expired".
  if s.status = 'expired' or (s.status = 'pending' and s.expires_at <= now()) then
    raise exception 'expired';
  end if;
  if s.status <> 'pending' then raise exception 'not_found'; end if;
  if s.viewer_id = me then raise exception 'self'; end if;
  if not exists (
    select 1 from public.friendships
    where user_a = least(me, s.viewer_id) and user_b = greatest(me, s.viewer_id)
  ) or public.is_blocked_between(me, s.viewer_id) then
    raise exception 'not_friends';
  end if;
  select * into who from public.profiles where id = s.viewer_id;
  return jsonb_build_object(
    'session_id', s.id, 'viewer_id', s.viewer_id,
    'display_name', coalesce(who.display_name, who.username, ''),
    'avatar_path', who.avatar_path);
end;
$$;

create or replace function public.join_pov(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  s public.pov_sessions;
  who uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into s from public.pov_sessions where code = btrim(coalesce(p_code, ''));
  if s.id is null then raise exception 'not_found'; end if;

  -- Both people locked in the same order, so two scans cannot both get through.
  for who in select unnest(array[least(me, s.viewer_id), greatest(me, s.viewer_id)]) loop
    perform pg_advisory_xact_lock(hashtextextended(who::text, 0));
  end loop;
  perform public.pov_sweep(me);
  perform public.pov_sweep(s.viewer_id);

  select * into s from public.pov_sessions
  where code = btrim(coalesce(p_code, '')) for update;
  if s.id is null then raise exception 'not_found'; end if;
  -- The sweep above may just have closed it: that is still "expired", not "not found".
  if s.status = 'expired' or (s.status = 'pending' and s.expires_at <= now()) then
    raise exception 'expired';
  end if;
  if s.status <> 'pending' then raise exception 'not_found'; end if;
  if s.viewer_id = me then raise exception 'self'; end if;
  if not exists (
    select 1 from public.friendships
    where user_a = least(me, s.viewer_id) and user_b = greatest(me, s.viewer_id)
  ) or public.is_blocked_between(me, s.viewer_id) then
    raise exception 'not_friends';
  end if;
  if public.pov_is_busy(me) then raise exception 'busy'; end if;

  update public.pov_sessions
  set host_id = me, status = 'accepted', answered_at = now(), code = null
  where id = s.id;
  return jsonb_build_object('session_id', s.id, 'viewer_id', s.viewer_id);
end;
$$;
