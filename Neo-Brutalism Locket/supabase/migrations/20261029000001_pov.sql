-- Omni POV: a friend sees, live, what my camera sees, so they can fix their pose.
--
-- A (the viewer) is the person being photographed: A asks a friend. B (the host) is the
-- person taking the photos: B says yes, and A watches B's camera while B takes as many
-- photos as they like. Only B takes photos. The picture itself goes straight from phone to
-- phone (WebRTC); this file is only about who may ask whom, and who may talk to whom.
--
--   pending    A asked, B has not answered (45 seconds)
--   accepted   B said yes: the two phones can connect and A watches
--   declined   B said no
--   cancelled  A took the request back
--   expired    nobody answered in time
--   ended      one of them stopped it (or it ran for 30 minutes)
--
-- Clients read their own sessions (and hear about changes through Realtime); every change
-- goes through the RPCs below.

create table public.pov_sessions (
  id uuid primary key default gen_random_uuid(),
  viewer_id uuid not null references public.profiles (id) on delete cascade, -- A
  host_id uuid not null references public.profiles (id) on delete cascade,   -- B
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired', 'ended')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '45 seconds',
  answered_at timestamptz,
  ended_at timestamptz,
  -- Photos B has taken in this session (A sees the count go up).
  shots int not null default 0 check (shots >= 0),
  -- How many times the `pov-ice` function has handed out relay credentials for it.
  ice_calls int not null default 0 check (ice_calls >= 0),
  check (viewer_id <> host_id)
);
create index pov_sessions_viewer_idx on public.pov_sessions (viewer_id, status);
create index pov_sessions_host_idx on public.pov_sessions (host_id, status);

alter table public.pov_sessions enable row level security;
create policy "viewer and host read their sessions"
  on public.pov_sessions for select to authenticated
  using ((select auth.uid()) in (viewer_id, host_id));
grant select on public.pov_sessions to authenticated;
-- The `pov-ice` Edge Function reads a session and counts its calls, as the service role.
grant select on public.pov_sessions to service_role;
grant update (ice_calls) on public.pov_sessions to service_role;

-- A new request reaches B at once, and A hears the answer.
alter publication supabase_realtime add table public.pov_sessions;

-- Helpers -----------------------------------------------------------------------------------
-- Closes what has run out of time, for one person's sessions: a request nobody answered in
-- 45 seconds, and a session that ran for 30 minutes. Run first by every RPC, so the table
-- never needs a scheduler.
create function public.pov_sweep(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  update public.pov_sessions
  set status = 'expired', ended_at = now()
  where p_user in (viewer_id, host_id)
    and status = 'pending' and expires_at <= now();
  update public.pov_sessions
  set status = 'ended', ended_at = now()
  where p_user in (viewer_id, host_id)
    and status = 'accepted' and answered_at <= now() - interval '30 minutes';
$$;
revoke all on function public.pov_sweep(uuid) from public, anon, authenticated;

-- Is this person in a session that is not over (after the sweep)?
create function public.pov_is_busy(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pov_sessions
    where p_user in (viewer_id, host_id) and status in ('pending', 'accepted'))
$$;
revoke all on function public.pov_is_busy(uuid) from public, anon, authenticated;

-- RPC: A asks a friend to show their camera ------------------------------------------------
-- Errors (message): not_signed_in, self, not_friends (also when blocked), busy (A or B is in
-- a session already), too_many (20 requests an hour).
create function public.request_pov(p_host uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  who uuid;
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_host is null or p_host = me then raise exception 'self'; end if;
  if not exists (
    select 1 from public.friendships
    where user_a = least(me, p_host) and user_b = greatest(me, p_host)
  ) or public.is_blocked_between(me, p_host) then
    raise exception 'not_friends';
  end if;

  -- Both people locked in the same order, so two requests cannot both get through.
  for who in select unnest(array[least(me, p_host), greatest(me, p_host)]) loop
    perform pg_advisory_xact_lock(hashtextextended(who::text, 0));
  end loop;
  perform public.pov_sweep(me);
  perform public.pov_sweep(p_host);
  if public.pov_is_busy(me) or public.pov_is_busy(p_host) then
    raise exception 'busy';
  end if;
  if (select count(*) from public.pov_sessions
      where viewer_id = me and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'too_many';
  end if;

  insert into public.pov_sessions (viewer_id, host_id) values (me, p_host)
  returning id into new_id;
  return new_id;
end;
$$;

-- RPC: B answers ----------------------------------------------------------------------------
-- Errors: not_signed_in, not_found (not mine, or no longer waiting), expired.
create function public.answer_pov(p_session uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  s public.pov_sessions;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  perform public.pov_sweep(me);
  select * into s from public.pov_sessions
  where id = p_session and host_id = me for update;
  if s.id is null then raise exception 'not_found'; end if;
  if s.status = 'expired' then raise exception 'expired'; end if;
  if s.status <> 'pending' then raise exception 'not_found'; end if;
  -- They may have stopped being friends (or blocked each other) while it was waiting.
  if p_accept and (
    not exists (
      select 1 from public.friendships
      where user_a = least(me, s.viewer_id) and user_b = greatest(me, s.viewer_id))
    or public.is_blocked_between(me, s.viewer_id)
  ) then
    p_accept := false;
  end if;
  update public.pov_sessions
  set status = case when p_accept then 'accepted' else 'declined' end,
      answered_at = now(),
      ended_at = case when p_accept then null else now() end
  where id = s.id;
end;
$$;

-- RPC: A takes the request back ---------------------------------------------------------------
create function public.cancel_pov(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  update public.pov_sessions
  set status = 'cancelled', ended_at = now()
  where id = p_session and viewer_id = auth.uid() and status = 'pending';
end;
$$;

-- RPC: either of them stops the session. Safe to call again. --------------------------------
create function public.end_pov(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  update public.pov_sessions
  set status = 'ended', ended_at = now()
  where id = p_session and auth.uid() in (viewer_id, host_id) and status = 'accepted';
end;
$$;

-- RPC: B has just taken a photo, so A's screen can say so. ------------------------------------
create function public.pov_shot(p_session uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  update public.pov_sessions
  set shots = shots + 1
  where id = p_session and host_id = auth.uid() and status = 'accepted';
end;
$$;

revoke all on function
  public.request_pov(uuid),
  public.answer_pov(uuid, boolean),
  public.cancel_pov(uuid),
  public.end_pov(uuid),
  public.pov_shot(uuid)
from public, anon;
grant execute on function
  public.request_pov(uuid),
  public.answer_pov(uuid, boolean),
  public.cancel_pov(uuid),
  public.end_pov(uuid),
  public.pov_shot(uuid)
to authenticated;

-- The private channel the two phones use to set up the connection ------------------------------
-- Topic `pov:<session id>`: only the two people of a session that is accepted may read or
-- write it. (Only small set-up messages go through it; the picture does not.)
do $$
begin
  if to_regclass('realtime.messages') is not null then
    create policy "pov: the two of an accepted session can listen"
      on realtime.messages for select to authenticated
      using (
        realtime.messages.extension = 'broadcast'
        and exists (
          select 1 from public.pov_sessions s
          where s.status = 'accepted'
            and 'pov:' || s.id::text = (select realtime.topic())
            and (select auth.uid()) in (s.viewer_id, s.host_id)));
    create policy "pov: the two of an accepted session can speak"
      on realtime.messages for insert to authenticated
      with check (
        realtime.messages.extension = 'broadcast'
        and exists (
          select 1 from public.pov_sessions s
          where s.status = 'accepted'
            and 'pov:' || s.id::text = (select realtime.topic())
            and (select auth.uid()) in (s.viewer_id, s.host_id)));
  end if;
end $$;

-- Push: tell B when a request comes in ---------------------------------------------------------
-- The same trigger function as the other pushes, with one more kind of event.
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
      when 'pov_sessions' then jsonb_build_object(
        'type', 'pov_request', 'from', rec ->> 'viewer_id', 'to', rec ->> 'host_id',
        'session_id', rec ->> 'id')
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

create trigger push_pov_request after insert on public.pov_sessions
  for each row execute function public.notify_push();
