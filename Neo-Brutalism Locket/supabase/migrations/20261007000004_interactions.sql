-- Interactions: emoji reactions, "seen by", chat messages and deleting a post.
-- Clients read; every change goes through the RPCs below.

-- Reactions: one emoji per person per post (changing it replaces the old one).
-- Only the author and the reacting person can see a reaction (like Locket).
create table public.post_reactions (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- Views: who opened a post. Only the author sees the list.
create table public.post_views (
  post_id uuid not null references public.posts (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (post_id, viewer_id)
);

-- Messages between two friends, optionally replying to a post.
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  post_id uuid references public.posts (id) on delete set null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (sender_id <> recipient_id)
);
create index messages_recipient_idx
  on public.messages (recipient_id, created_at desc);
create index messages_sender_idx on public.messages (sender_id, created_at desc);

alter table public.post_reactions enable row level security;
alter table public.post_views enable row level security;
alter table public.messages enable row level security;

create policy "author and reactor read reactions"
  on public.post_reactions for select to authenticated
  using (user_id = (select auth.uid()) or public.is_post_author(post_id));

create policy "author and viewer read views"
  on public.post_views for select to authenticated
  using (viewer_id = (select auth.uid()) or public.is_post_author(post_id));

create policy "sender and recipient read messages"
  on public.messages for select to authenticated
  using ((select auth.uid()) in (sender_id, recipient_id));

grant select on public.post_reactions, public.post_views, public.messages
  to authenticated;

-- Can I see this post as a recipient (not as its author)? Internal helper.
create function public.is_post_recipient(p_post uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.post_recipients r
    join public.posts p on p.id = r.post_id
    where r.post_id = p_post and r.user_id = auth.uid() and p.deleted_at is null
  )
$$;
revoke all on function public.is_post_recipient(uuid) from public, anon;
grant execute on function public.is_post_recipient(uuid) to authenticated;

-- RPC: react to a post I received. p_emoji = null takes my reaction back. -------------
-- Errors: not_signed_in, not_found (not a recipient / deleted), bad_emoji.
create function public.react_to_post(p_post uuid, p_emoji text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.is_post_recipient(p_post) then raise exception 'not_found'; end if;
  if p_emoji is null or btrim(p_emoji) = '' then
    delete from public.post_reactions where post_id = p_post and user_id = me;
    return;
  end if;
  if char_length(p_emoji) > 16 then raise exception 'bad_emoji'; end if;
  insert into public.post_reactions (post_id, user_id, emoji)
  values (p_post, me, p_emoji)
  on conflict (post_id, user_id)
  do update set emoji = excluded.emoji, created_at = now();
end;
$$;

-- RPC: I opened a post I received. Safe to call again. ----------------------------------
create function public.mark_post_viewed(p_post uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if not public.is_post_recipient(p_post) then return; end if;
  insert into public.post_views (post_id, viewer_id)
  values (p_post, auth.uid())
  on conflict do nothing;
end;
$$;

-- RPC: delete my post. It disappears for everyone; files are removed by the app. ----------
create function public.delete_post(p_post uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  update public.posts set deleted_at = now()
  where id = p_post and author_id = auth.uid() and deleted_at is null;
end;
$$;

-- RPC: send a message to a friend, optionally about a post. --------------------------------
-- Errors: not_signed_in, empty, too_long, not_found (not friends / blocked / bad post).
create function public.send_message(
  p_to uuid,
  p_body text,
  p_post uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  text_body text := btrim(coalesce(p_body, ''));
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if text_body = '' then raise exception 'empty'; end if;
  if char_length(text_body) > 500 then raise exception 'too_long'; end if;
  if not exists (
    select 1 from public.friendships
    where user_a = least(me, p_to) and user_b = greatest(me, p_to)
  ) or public.is_blocked_between(me, p_to) then
    raise exception 'not_found';
  end if;
  if p_post is not null and not exists (
    select 1 from public.posts
    where id = p_post and deleted_at is null and author_id in (me, p_to)
  ) then
    raise exception 'not_found';
  end if;
  insert into public.messages (sender_id, recipient_id, body, post_id)
  values (me, p_to, text_body, p_post)
  returning id into new_id;
  return new_id;
end;
$$;

-- RPC: I read the conversation with a friend. ----------------------------------------------
create function public.mark_thread_read(p_with uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  update public.messages set read_at = now()
  where recipient_id = auth.uid() and sender_id = p_with and read_at is null;
end;
$$;

revoke all on function
  public.react_to_post(uuid, text),
  public.mark_post_viewed(uuid),
  public.delete_post(uuid),
  public.send_message(uuid, text, uuid),
  public.mark_thread_read(uuid)
from public, anon;
grant execute on function
  public.react_to_post(uuid, text),
  public.mark_post_viewed(uuid),
  public.delete_post(uuid),
  public.send_message(uuid, text, uuid),
  public.mark_thread_read(uuid)
to authenticated;

-- Live updates: new messages for the recipient, new reactions for the author.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.post_reactions;
