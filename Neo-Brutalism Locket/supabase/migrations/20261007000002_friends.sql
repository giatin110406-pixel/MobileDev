-- Friends: requests, friendships and blocks.
-- Clients only READ these tables; every change goes through the RPCs below, which
-- enforce the rules (max 20 friends, no self/duplicate requests, blocks).

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references public.profiles (id) on delete cascade,
  to_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (from_id <> to_id)
);

-- At most one open request between two people, whichever way it points.
create unique index friend_requests_one_pending_per_pair
  on public.friend_requests (least(from_id, to_id), greatest(from_id, to_id))
  where status = 'pending';
create index friend_requests_to_idx on public.friend_requests (to_id, status);
create index friend_requests_from_idx on public.friend_requests (from_id, status);

create table public.friendships (
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index friendships_b_idx on public.friendships (user_b);

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

-- Row-level security: read-only for the two people involved ------------------------
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.blocks enable row level security;

create policy "request parties read requests"
  on public.friend_requests for select to authenticated
  using ((select auth.uid()) in (from_id, to_id));

create policy "friends read their friendships"
  on public.friendships for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));

create policy "blockers read their blocks"
  on public.blocks for select to authenticated
  using (blocker_id = (select auth.uid()));

-- New tables are not auto-exposed in this project: grant read access only.
grant select on public.friend_requests, public.friendships, public.blocks
  to authenticated;

-- Helpers ---------------------------------------------------------------------------
create function public.friend_limit() returns int
language sql immutable as $$ select 20 $$;

create function public.friend_count(p_user uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.friendships
  where user_a = p_user or user_b = p_user
$$;

create function public.is_blocked_between(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = p_a and blocked_id = p_b)
       or (blocker_id = p_b and blocked_id = p_a)
  )
$$;

-- Helpers are internal: not callable by clients.
revoke all on function public.friend_count(uuid) from public, anon, authenticated;
revoke all on function public.is_blocked_between(uuid, uuid)
  from public, anon, authenticated;

-- Creates the friendship for two people (order-normalised). Internal.
create function public.make_friends(p_one uuid, p_two uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if public.friend_count(p_one) >= public.friend_limit() then
    raise exception 'friend_limit';
  end if;
  if public.friend_count(p_two) >= public.friend_limit() then
    raise exception 'their_friend_limit';
  end if;
  insert into public.friendships (user_a, user_b)
  values (least(p_one, p_two), greatest(p_one, p_two))
  on conflict do nothing;
end;
$$;
revoke all on function public.make_friends(uuid, uuid)
  from public, anon, authenticated;

-- RPC: send a request by username ---------------------------------------------------
-- Errors (message): not_found, self, already_friends, already_sent, not_accepting,
-- too_many_pending, friend_limit, their_friend_limit.
-- If they already asked me, this accepts it (mutual) and returns 'accepted'.
create function public.send_friend_request(p_username text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  target public.profiles;
  incoming public.friend_requests;
begin
  if me is null then raise exception 'not_signed_in'; end if;

  select * into target from public.profiles
  where username = lower(trim(both '@' from trim(p_username)));
  -- A blocked person looks exactly like a missing one.
  if target.id is null or public.is_blocked_between(me, target.id) then
    raise exception 'not_found';
  end if;
  if target.id = me then raise exception 'self'; end if;

  if exists (
    select 1 from public.friendships
    where user_a = least(me, target.id) and user_b = greatest(me, target.id)
  ) then
    raise exception 'already_friends';
  end if;

  select * into incoming from public.friend_requests
  where from_id = target.id and to_id = me and status = 'pending';
  if incoming.id is not null then
    perform public.make_friends(me, target.id);
    update public.friend_requests
      set status = 'accepted', responded_at = now()
      where id = incoming.id;
    return 'accepted';
  end if;

  if exists (
    select 1 from public.friend_requests
    where from_id = me and to_id = target.id and status = 'pending'
  ) then
    raise exception 'already_sent';
  end if;
  if not target.allow_requests then raise exception 'not_accepting'; end if;
  if (select count(*) from public.friend_requests
      where from_id = me and status = 'pending') >= 20 then
    raise exception 'too_many_pending';
  end if;
  if public.friend_count(me) >= public.friend_limit() then
    raise exception 'friend_limit';
  end if;

  insert into public.friend_requests (from_id, to_id) values (me, target.id);
  return 'sent';
end;
$$;

-- RPC: answer a request sent to me ---------------------------------------------------
create function public.respond_friend_request(p_id uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  req public.friend_requests;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into req from public.friend_requests
  where id = p_id and to_id = me and status = 'pending'
  for update;
  if req.id is null then raise exception 'not_found'; end if;

  if p_accept then
    if public.is_blocked_between(me, req.from_id) then
      raise exception 'not_found';
    end if;
    perform public.make_friends(me, req.from_id);
    update public.friend_requests
      set status = 'accepted', responded_at = now() where id = req.id;
  else
    update public.friend_requests
      set status = 'declined', responded_at = now() where id = req.id;
  end if;
end;
$$;

-- RPC: take back a request I sent ---------------------------------------------------
create function public.cancel_friend_request(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.friend_requests
  where id = p_id and from_id = auth.uid() and status = 'pending';
end;
$$;

-- RPC: end a friendship --------------------------------------------------------------
create function public.remove_friend(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  delete from public.friendships
  where user_a = least(me, p_user) and user_b = greatest(me, p_user);
end;
$$;

revoke all on function
  public.send_friend_request(text),
  public.respond_friend_request(uuid, boolean),
  public.cancel_friend_request(uuid),
  public.remove_friend(uuid)
from public, anon;
grant execute on function
  public.send_friend_request(text),
  public.respond_friend_request(uuid, boolean),
  public.cancel_friend_request(uuid),
  public.remove_friend(uuid)
to authenticated;

-- Search by username prefix (own profile excluded, blocked people hidden) -------------
create function public.search_profiles(p_query text)
returns setof public.profiles
language sql stable security definer set search_path = '' as $$
  select p.* from public.profiles p
  where auth.uid() is not null
    and p.username is not null
    and p.id <> auth.uid()
    and char_length(trim(p_query)) >= 2
    and p.username like
      replace(replace(replace(lower(trim(both '@' from trim(p_query))), '\', '\\'), '%', '\%'), '_', '\_') || '%'
    and not public.is_blocked_between(auth.uid(), p.id)
  order by p.username
  limit 10
$$;
revoke all on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;
