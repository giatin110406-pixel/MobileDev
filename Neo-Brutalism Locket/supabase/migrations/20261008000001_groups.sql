-- Groups: a small circle that chats and (later) paints a shared canvas.
--
-- Being in the same group does NOT make two people friends. Nothing here touches
-- posts, post_recipients or the media bucket, so the feed stays friends-only.
-- Group data (members, messages) is readable only by members. Clients read;
-- every change goes through the RPCs below.
--
-- The owner is the member whose role is 'owner' (exactly one per live group), not a
-- column on groups: deleting the owner's account must not delete the group.

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  avatar_path text,
  rules text not null default '' check (char_length(rules) <= 500),
  max_members int not null default 12 check (max_members between 2 and 12),
  created_at timestamptz not null default now(),
  dissolved_at timestamptz
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user_idx on public.group_members (user_id);
-- Exactly one owner per group.
create unique index group_members_one_owner
  on public.group_members (group_id) where role = 'owner';

create table public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  invitee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  check (inviter_id <> invitee_id)
);
create unique index group_invites_one_pending
  on public.group_invites (group_id, invitee_id) where status = 'pending';
create index group_invites_invitee_idx on public.group_invites (invitee_id, status);

create table public.group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  -- For kind = 'system' this is the person the event is about.
  sender_id uuid references public.profiles (id) on delete set null,
  kind text not null default 'text' check (kind in ('text', 'system')),
  -- Text: what was typed. System: a code (joined, left, kicked, owner_changed).
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index group_messages_group_idx
  on public.group_messages (group_id, created_at desc);

create table public.group_reads (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- Helpers used by policies ------------------------------------------------------------
-- Policies on groups and group_members cannot query each other (infinite
-- recursion), so they ask these security-definer functions instead.

create function public.is_group_member(p_group uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.group_members m
    join public.groups g on g.id = m.group_id
    where m.group_id = p_group and m.user_id = auth.uid()
      and g.dissolved_at is null
  )
$$;

-- May I read this message? A member, from the day I joined, and not from
-- someone I blocked or who blocked me.
create function public.group_message_visible(
  p_group uuid, p_sender uuid, p_created timestamptz
) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.group_members m
    join public.groups g on g.id = m.group_id
    where m.group_id = p_group and m.user_id = auth.uid()
      and g.dissolved_at is null
      and p_created >= m.joined_at
  ) and (
    p_sender is null or p_sender = auth.uid()
    or not public.is_blocked_between(auth.uid(), p_sender)
  )
$$;

revoke all on function public.is_group_member(uuid) from public, anon;
revoke all on function public.group_message_visible(uuid, uuid, timestamptz)
  from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.group_message_visible(uuid, uuid, timestamptz)
  to authenticated;

-- Row-level security ----------------------------------------------------------------------
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;
alter table public.group_messages enable row level security;
alter table public.group_reads enable row level security;

create policy "members read their groups"
  on public.groups for select to authenticated
  using (public.is_group_member(id));

create policy "members read the member list"
  on public.group_members for select to authenticated
  using (public.is_group_member(group_id));

create policy "invite parties read invites"
  on public.group_invites for select to authenticated
  using ((select auth.uid()) in (inviter_id, invitee_id));

create policy "members read messages"
  on public.group_messages for select to authenticated
  using (public.group_message_visible(group_id, sender_id, created_at));

create policy "people read their own read marks"
  on public.group_reads for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.groups, public.group_members, public.group_invites,
  public.group_messages, public.group_reads to authenticated;

-- Internal helpers ---------------------------------------------------------------------------
create function public.group_post_system(
  p_group uuid, p_user uuid, p_code text
) returns void
language sql security definer set search_path = '' as $$
  insert into public.group_messages (group_id, sender_id, kind, body)
  values (p_group, p_user, 'system', p_code)
$$;

create function public.group_is_owner(p_group uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members m
    join public.groups g on g.id = m.group_id
    where m.group_id = p_group and m.user_id = p_user
      and m.role = 'owner' and g.dissolved_at is null
  )
$$;

revoke all on function
  public.group_post_system(uuid, uuid, text),
  public.group_is_owner(uuid, uuid)
from public, anon, authenticated;

-- When an owner's membership disappears (account deleted), the longest-standing
-- member takes over; with nobody left the group is dissolved.
create function public.group_owner_gone() returns trigger
language plpgsql security definer set search_path = '' as $$
declare heir uuid;
begin
  if old.role <> 'owner' then return old; end if;
  select user_id into heir from public.group_members
  where group_id = old.group_id order by joined_at, user_id limit 1;
  if heir is null then
    update public.groups set dissolved_at = now()
    where id = old.group_id and dissolved_at is null;
  else
    update public.group_members set role = 'owner'
    where group_id = old.group_id and user_id = heir;
    perform public.group_post_system(old.group_id, heir, 'owner_changed');
  end if;
  return old;
end;
$$;
revoke all on function public.group_owner_gone() from public, anon, authenticated;

create trigger group_owner_gone after delete on public.group_members
  for each row execute function public.group_owner_gone();

-- RPCs ---------------------------------------------------------------------------------------
-- Errors (message): not_signed_in, not_found, not_owner, not_member, self, empty,
-- too_long, bad_name, bad_size, group_limit, member_limit, their_group_limit,
-- already_member, already_invited, expired, owner_must_transfer.

create function public.create_group(
  p_name text,
  p_rules text default '',
  p_max_members int default 12
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  gid uuid;
  clean text := btrim(coalesce(p_name, ''));
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if char_length(clean) not between 1 and 40 then raise exception 'bad_name'; end if;
  if char_length(coalesce(p_rules, '')) > 500 then raise exception 'too_long'; end if;
  if p_max_members not between 2 and 12 then raise exception 'bad_size'; end if;
  if (select count(*) from public.group_members m
      join public.groups g on g.id = m.group_id
      where m.user_id = me and m.role = 'owner' and g.dissolved_at is null) >= 3
     or (select count(*) from public.group_members m
         join public.groups g on g.id = m.group_id
         where m.user_id = me and g.dissolved_at is null) >= 5 then
    raise exception 'group_limit';
  end if;

  insert into public.groups (name, rules, max_members)
  values (clean, coalesce(p_rules, ''), p_max_members)
  returning id into gid;
  insert into public.group_members (group_id, user_id, role)
  values (gid, me, 'owner');
  return gid;
end;
$$;

create function public.update_group(
  p_group uuid,
  p_name text,
  p_rules text,
  p_max_members int,
  p_avatar_path text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  clean text := btrim(coalesce(p_name, ''));
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if char_length(clean) not between 1 and 40 then raise exception 'bad_name'; end if;
  if char_length(coalesce(p_rules, '')) > 500 then raise exception 'too_long'; end if;
  if p_max_members not between 2 and 12 then raise exception 'bad_size'; end if;
  -- Cannot shrink below who is already in.
  if p_max_members < (select count(*) from public.group_members
                      where group_id = p_group) then
    raise exception 'bad_size';
  end if;
  if p_avatar_path is not null and p_avatar_path not like (me::text || '/%') then
    raise exception 'bad_path';
  end if;
  update public.groups
    set name = clean,
        rules = coalesce(p_rules, ''),
        max_members = p_max_members,
        avatar_path = coalesce(p_avatar_path, avatar_path)
    where id = p_group;
end;
$$;

-- Owner invites one of THEIR OWN friends. Strangers stay strangers: the people in a
-- group are not necessarily friends with each other.
create function public.invite_to_group(p_group uuid, p_user uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  g public.groups;
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if p_user = me then raise exception 'self'; end if;
  -- A blocked person looks exactly like a missing one.
  if public.is_blocked_between(me, p_user) or not exists (
    select 1 from public.friendships
    where user_a = least(me, p_user) and user_b = greatest(me, p_user)
  ) then
    raise exception 'not_found';
  end if;
  select * into g from public.groups where id = p_group for update;
  if exists (select 1 from public.group_members
             where group_id = p_group and user_id = p_user) then
    raise exception 'already_member';
  end if;
  if exists (select 1 from public.group_invites
             where group_id = p_group and invitee_id = p_user
               and status = 'pending' and expires_at > now()) then
    raise exception 'already_invited';
  end if;
  -- Pending invites hold a seat so the cap cannot be passed.
  if (select count(*) from public.group_members where group_id = p_group)
     + (select count(*) from public.group_invites
        where group_id = p_group and status = 'pending' and expires_at > now())
     >= g.max_members then
    raise exception 'member_limit';
  end if;
  update public.group_invites set status = 'revoked'
    where group_id = p_group and invitee_id = p_user and status = 'pending';
  insert into public.group_invites (group_id, inviter_id, invitee_id)
  values (p_group, me, p_user)
  returning id into new_id;
  return new_id;
end;
$$;

create function public.respond_group_invite(p_id uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  inv public.group_invites;
  g public.groups;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into inv from public.group_invites
  where id = p_id and invitee_id = me and status = 'pending'
  for update;
  if inv.id is null then raise exception 'not_found'; end if;

  if not p_accept then
    update public.group_invites set status = 'declined' where id = inv.id;
    return;
  end if;

  select * into g from public.groups
  where id = inv.group_id and dissolved_at is null for update;
  if g.id is null then raise exception 'not_found'; end if;
  if inv.expires_at <= now() then raise exception 'expired'; end if;
  if (select count(*) from public.group_members where group_id = g.id)
     >= g.max_members then
    raise exception 'member_limit';
  end if;
  if (select count(*) from public.group_members m
      join public.groups gg on gg.id = m.group_id
      where m.user_id = me and gg.dissolved_at is null) >= 5 then
    raise exception 'their_group_limit';
  end if;

  insert into public.group_members (group_id, user_id) values (g.id, me)
  on conflict do nothing;
  update public.group_invites set status = 'accepted' where id = inv.id;
  perform public.group_post_system(g.id, me, 'joined');
end;
$$;

create function public.revoke_group_invite(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  update public.group_invites set status = 'revoked'
  where id = p_id and status = 'pending'
    and public.group_is_owner(group_id, me);
end;
$$;

create function public.kick_member(p_group uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if p_user = me then raise exception 'self'; end if;
  delete from public.group_members where group_id = p_group and user_id = p_user;
  if found then
    perform public.group_post_system(p_group, p_user, 'kicked');
  end if;
end;
$$;

create function public.transfer_ownership(p_group uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  if p_user = me then raise exception 'self'; end if;
  if not exists (select 1 from public.group_members
                 where group_id = p_group and user_id = p_user) then
    raise exception 'not_member';
  end if;
  -- Two statements: the unique index allows one owner at a time.
  update public.group_members set role = 'member'
    where group_id = p_group and user_id = me;
  update public.group_members set role = 'owner'
    where group_id = p_group and user_id = p_user;
  perform public.group_post_system(p_group, p_user, 'owner_changed');
end;
$$;

-- Leaving. The owner must hand the group over first; the last person out closes it.
create function public.leave_group(p_group uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  others int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.is_group_member(p_group) then raise exception 'not_member'; end if;
  select count(*) into others from public.group_members
  where group_id = p_group and user_id <> me;
  if public.group_is_owner(p_group, me) and others > 0 then
    raise exception 'owner_must_transfer';
  end if;
  -- Last member out: the trigger dissolves the group.
  delete from public.group_members where group_id = p_group and user_id = me;
  if others > 0 then
    perform public.group_post_system(p_group, me, 'left');
  end if;
end;
$$;

create function public.dissolve_group(p_group uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.group_is_owner(p_group, me) then raise exception 'not_owner'; end if;
  update public.groups set dissolved_at = now() where id = p_group;
  update public.group_invites set status = 'revoked'
    where group_id = p_group and status = 'pending';
end;
$$;

create function public.send_group_message(p_group uuid, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  text_body text := btrim(coalesce(p_body, ''));
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if text_body = '' then raise exception 'empty'; end if;
  if char_length(text_body) > 500 then raise exception 'too_long'; end if;
  if not public.is_group_member(p_group) then raise exception 'not_member'; end if;
  insert into public.group_messages (group_id, sender_id, kind, body)
  values (p_group, me, 'text', text_body)
  returning id into new_id;
  return new_id;
end;
$$;

create function public.mark_group_read(p_group uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if not public.is_group_member(p_group) then return; end if;
  insert into public.group_reads (group_id, user_id) values (p_group, auth.uid())
  on conflict (group_id, user_id) do update set last_read_at = now();
end;
$$;

revoke all on function
  public.create_group(text, text, int),
  public.update_group(uuid, text, text, int, text),
  public.invite_to_group(uuid, uuid),
  public.respond_group_invite(uuid, boolean),
  public.revoke_group_invite(uuid),
  public.kick_member(uuid, uuid),
  public.transfer_ownership(uuid, uuid),
  public.leave_group(uuid),
  public.dissolve_group(uuid),
  public.send_group_message(uuid, text),
  public.mark_group_read(uuid)
from public, anon;
grant execute on function
  public.create_group(text, text, int),
  public.update_group(uuid, text, text, int, text),
  public.invite_to_group(uuid, uuid),
  public.respond_group_invite(uuid, boolean),
  public.revoke_group_invite(uuid),
  public.kick_member(uuid, uuid),
  public.transfer_ownership(uuid, uuid),
  public.leave_group(uuid),
  public.dissolve_group(uuid),
  public.send_group_message(uuid, text),
  public.mark_group_read(uuid)
to authenticated;

-- New messages and member changes reach open screens (RLS still applies).
alter publication supabase_realtime add table public.group_messages;
alter publication supabase_realtime add table public.group_members;
