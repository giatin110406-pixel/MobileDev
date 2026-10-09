-- Push notifications: which phones belong to whom, what each person wants to
-- hear about, and the triggers that tell the `notify` Edge Function when
-- something happens (a new post, a message, a reaction, a friend request).
--
-- The triggers do nothing until the two Vault secrets named below exist, so
-- applying this migration is safe before the push setup is finished. See
-- supabase/PUSH_SETUP.md.

create extension if not exists pg_net with schema extensions;

-- Phones that may receive pushes ------------------------------------------------------------
create table public.device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null default 'android' check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;
create policy "owners read their devices"
  on public.device_tokens for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.device_tokens to authenticated;

-- What each person wants to hear about ------------------------------------------------------
create table public.notification_prefs (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  new_post boolean not null default true,
  messages boolean not null default true,
  reactions boolean not null default true,
  friend_requests boolean not null default true
);

alter table public.notification_prefs enable row level security;
create policy "owners read their notification settings"
  on public.notification_prefs for select to authenticated
  using (user_id = (select auth.uid()));
create policy "owners create their notification settings"
  on public.notification_prefs for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "owners change their notification settings"
  on public.notification_prefs for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
grant select, insert, update on public.notification_prefs to authenticated;

-- RPC: this phone belongs to me now --------------------------------------------------------
-- A token is one phone. If someone else signed in on it before, it moves.
create function public.register_device(p_token text, p_platform text default 'android')
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if p_token is null or char_length(p_token) < 20 or char_length(p_token) > 4096 then
    raise exception 'bad_token';
  end if;
  if p_platform not in ('android', 'ios') then raise exception 'bad_platform'; end if;
  insert into public.device_tokens (token, user_id, platform)
  values (p_token, auth.uid(), p_platform)
  on conflict (token)
  do update set user_id = excluded.user_id,
                platform = excluded.platform,
                updated_at = now();
end;
$$;

-- RPC: stop sending pushes to this phone (sign out) ------------------------------------------
create function public.unregister_device(p_token text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
end;
$$;

revoke all on function
  public.register_device(text, text),
  public.unregister_device(text)
from public, anon;
grant execute on function
  public.register_device(text, text),
  public.unregister_device(text)
to authenticated;

-- Telling the Edge Function --------------------------------------------------------------------
-- Reads the function's address and shared secret from Vault; no secret is in
-- this file. Never blocks or fails the change that fired it.
create function public.notify_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  base_url text;
  secret text;
  -- One function serves four tables, so read the row as JSON: naming a column
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

create trigger push_new_post after insert on public.post_recipients
  for each row execute function public.notify_push();
create trigger push_message after insert on public.messages
  for each row execute function public.notify_push();
create trigger push_reaction after insert on public.post_reactions
  for each row execute function public.notify_push();
create trigger push_friend_request after insert on public.friend_requests
  for each row execute function public.notify_push();
create trigger push_friend_accepted after update of status on public.friend_requests
  for each row when (old.status = 'pending' and new.status = 'accepted')
  execute function public.notify_push();
