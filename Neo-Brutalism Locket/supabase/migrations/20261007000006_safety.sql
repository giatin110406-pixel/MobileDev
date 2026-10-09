-- Safety: blocking, reporting and deleting your own account.

-- Reports: anyone signed in can file one (through report_content); nobody can
-- read them from the app. Look at them in the Supabase dashboard.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  -- No foreign key on purpose: the report stays if that person leaves.
  target_user uuid,
  target_post uuid references public.posts (id) on delete set null,
  reason text not null check (reason in ('spam', 'inappropriate', 'harassment', 'other')),
  details text check (char_length(details) <= 500),
  created_at timestamptz not null default now(),
  check (target_user is not null or target_post is not null)
);
create index reports_reporter_idx on public.reports (reporter_id, created_at desc);

alter table public.reports enable row level security;
-- No policies and no grants: clients cannot read or write reports directly.

-- RPC: block someone ---------------------------------------------------------------------
-- Ends the friendship, cancels open requests and hides each other's posts.
-- They are not told. Errors: not_signed_in, self, not_found.
create function public.block_user(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_user = me then raise exception 'self'; end if;
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'not_found';
  end if;

  insert into public.blocks (blocker_id, blocked_id) values (me, p_user)
  on conflict do nothing;

  delete from public.friendships
  where user_a = least(me, p_user) and user_b = greatest(me, p_user);
  delete from public.friend_requests
  where status = 'pending'
    and ((from_id = me and to_id = p_user) or (from_id = p_user and to_id = me));
  -- Posts each sent the other stop being visible.
  delete from public.post_recipients r
  using public.posts p
  where r.post_id = p.id
    and ((p.author_id = p_user and r.user_id = me)
      or (p.author_id = me and r.user_id = p_user));
end;
$$;

create function public.unblock_user(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  delete from public.blocks
  where blocker_id = auth.uid() and blocked_id = p_user;
end;
$$;

-- RPC: report a person or a post I received ------------------------------------------------
-- Errors: not_signed_in, nothing_to_report, bad_reason, too_long, not_found,
-- too_many (20 reports a day is plenty).
create function public.report_content(
  p_user uuid,
  p_post uuid,
  p_reason text,
  p_details text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  target uuid := p_user;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_user is null and p_post is null then raise exception 'nothing_to_report'; end if;
  if p_reason not in ('spam', 'inappropriate', 'harassment', 'other') then
    raise exception 'bad_reason';
  end if;
  if char_length(coalesce(p_details, '')) > 500 then raise exception 'too_long'; end if;

  if p_post is not null then
    if not public.is_post_recipient(p_post) then raise exception 'not_found'; end if;
    select author_id into target from public.posts where id = p_post;
  end if;
  if target = me then raise exception 'not_found'; end if;

  if (select count(*) from public.reports
      where reporter_id = me and created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many';
  end if;

  insert into public.reports (reporter_id, target_user, target_post, reason, details)
  values (me, target, p_post, p_reason, nullif(btrim(coalesce(p_details, '')), ''));
end;
$$;

-- RPC: delete my account and everything that belongs to it ---------------------------------
-- Profile, friendships, posts, messages, Sunbit... all follow from the auth user
-- through "on delete cascade". The app removes the picture files first (through
-- the storage API: deleting rows here would leave the files behind).
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function
  public.block_user(uuid),
  public.unblock_user(uuid),
  public.report_content(uuid, uuid, text, text),
  public.delete_my_account()
from public, anon;
grant execute on function
  public.block_user(uuid),
  public.unblock_user(uuid),
  public.report_content(uuid, uuid, text, text),
  public.delete_my_account()
to authenticated;
