-- Omni POV by QR code: no request, no answer.
--
-- A (the viewer, the person being photographed) taps the button and a QR code appears on
-- A's screen. B (the photographer) scans it with the app's camera, sees whose code it is,
-- confirms, and from then on A watches B's camera. The session is the same as before
-- (accepted, ended, 30 minutes at most, B takes the photos); only the way in changes.
--
--   pending    the code is on A's screen and nobody has scanned it (2 minutes)
--   accepted   B scanned and confirmed: the two phones can connect and A watches
--   cancelled  A closed the code     expired   nobody scanned it in time
--   ended      one of them stopped it (or it ran for 30 minutes)
--
-- Only friends: B must be A's friend (and not blocked), so a code that ends up in a
-- screenshot cannot open a stranger's camera. B is asked first, with A's name, before
-- anything is shared: scanning alone shares nothing.
--
-- The request / answer RPCs and the push for "a friend asks" are gone: nobody is asked
-- from afar any more.

-- The photographer is not known until the code is scanned.
alter table public.pov_sessions alter column host_id drop not null;
alter table public.pov_sessions drop constraint pov_sessions_check;
alter table public.pov_sessions
  add constraint pov_sessions_distinct_check
  check (host_id is null or viewer_id <> host_id);

-- What the QR code carries. Random (122 bits), used once, and kept only while it waits.
alter table public.pov_sessions add column code text unique;

-- A code lasts 2 minutes (a request used to wait 45 seconds).
alter table public.pov_sessions
  alter column expires_at set default now() + interval '2 minutes';

-- No more requests ---------------------------------------------------------------------------
drop trigger push_pov_request on public.pov_sessions;
drop function public.request_pov(uuid);
drop function public.answer_pov(uuid, boolean);

-- The same push function as before Omni POV: nothing is pushed for a session now.
create or replace function public.notify_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  base_url text;
  secret text;
  -- One function serves several tables, so read the row as JSON: naming a column
  -- the table does not have would be an error even in an unused branch.
  rec jsonb := to_jsonb(new);
  payload jsonb;
begin
  begin
    select decrypted_secret into base_url
      from vault.decrypted_secrets where name = 'project_url' limit 1;
    select decrypted_secret into secret
      from vault.decrypted_secrets where name = 'notify_secret' limit 1;
    if base_url is null or secret is null then
      return new; -- push is not set up yet
    end if;

    payload := case tg_table_name
      when 'post_recipients' then jsonb_build_object(
        'type', 'new_post', 'post_id', rec ->> 'post_id', 'to', rec ->> 'user_id')
      when 'messages' then jsonb_build_object(
        'type', 'message', 'from', rec ->> 'sender_id', 'to', rec ->> 'recipient_id',
        'body', left(rec ->> 'body', 140), 'post_id', rec ->> 'post_id')
      when 'post_reactions' then jsonb_build_object(
        'type', 'reaction', 'post_id', rec ->> 'post_id', 'from', rec ->> 'user_id',
        'emoji', rec ->> 'emoji')
      when 'friend_requests' then jsonb_build_object(
        'type', case when tg_op = 'INSERT' then 'friend_request' else 'friend_accepted' end,
        'from', rec ->> 'from_id', 'to', rec ->> 'to_id')
    end;
    if payload is null then return new; end if;

    perform net.http_post(
      url := rtrim(base_url, '/') || '/functions/v1/notify',
      body := payload,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-notify-secret', secret),
      timeout_milliseconds := 5000
    );
  exception when others then
    null; -- a push problem must never break sending a post or a message
  end;
  return new;
end;
$$;
revoke all on function public.notify_push() from public, anon, authenticated;

-- RPC: A opens the code ------------------------------------------------------------------------
-- Any code A still has on screen is replaced by this one. Errors (message): not_signed_in,
-- busy (A is in a session already), too_many (30 codes an hour).
-- Returns {session_id, code, expires_at}.
create function public.create_pov_code() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  s public.pov_sessions;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform pg_advisory_xact_lock(hashtextextended(me::text, 0));
  perform public.pov_sweep(me);
  update public.pov_sessions
  set status = 'cancelled', ended_at = now()
  where viewer_id = me and status = 'pending';
  if public.pov_is_busy(me) then raise exception 'busy'; end if;
  if (select count(*) from public.pov_sessions
      where viewer_id = me and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'too_many';
  end if;
  insert into public.pov_sessions (viewer_id, code)
  values (me, replace(gen_random_uuid()::text, '-', ''))
  returning * into s;
  return jsonb_build_object(
    'session_id', s.id, 'code', s.code, 'expires_at', s.expires_at);
end;
$$;

-- Whose code is this? ---------------------------------------------------------------------------
-- B scanned a code: this says whose it is (so B can be asked) without joining anything.
-- Errors: not_signed_in, not_found (no such code, or it was used or closed), expired, self,
-- not_friends (also when blocked: a stranger's code tells nothing).
-- Returns {session_id, viewer_id, display_name, avatar_path}.
create function public.peek_pov_code(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  s public.pov_sessions;
  who public.profiles;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into s from public.pov_sessions where code = btrim(coalesce(p_code, ''));
  if s.id is null or s.status <> 'pending' then raise exception 'not_found'; end if;
  if s.expires_at <= now() then raise exception 'expired'; end if;
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

-- RPC: B confirms ---------------------------------------------------------------------------------
-- B has been shown whose code it is and said yes: from now on A watches B's camera. The
-- code works once. Errors: not_signed_in, not_found, expired, self, not_friends, busy (B is
-- in a session already). Returns {session_id, viewer_id}.
create function public.join_pov(p_code text) returns jsonb
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
  if s.id is null or s.status <> 'pending' then raise exception 'not_found'; end if;
  if s.expires_at <= now() then raise exception 'expired'; end if;
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

revoke all on function
  public.create_pov_code(),
  public.peek_pov_code(text),
  public.join_pov(text)
from public, anon;
grant execute on function
  public.create_pov_code(),
  public.peek_pov_code(text),
  public.join_pov(text)
to authenticated;
