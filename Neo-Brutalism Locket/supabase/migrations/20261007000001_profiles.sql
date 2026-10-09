-- Profiles: one row per account, created automatically at sign-up.
-- username / display_name are filled in by onboarding.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique check (username ~ '^[a-z0-9._]{3,20}$'),
  display_name text check (char_length(display_name) between 1 and 40),
  avatar_path text,
  -- Equipped shop items. Changed only by the shop RPCs (later migration),
  -- never directly by the client (see the column grants below).
  frame_id text,
  banner_id text,
  allow_requests boolean not null default true,
  locale text not null default 'vi' check (locale in ('vi', 'en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Public profile of each account (readable by signed-in users).';

-- updated_at ---------------------------------------------------------------------
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Create the profile when the auth user is created ---------------------------------
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(left(coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      ''
    ), 40), '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row-level security ----------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "signed-in users read profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "users update their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- The project does not auto-expose new tables, so grant access explicitly.
grant select on public.profiles to authenticated;

-- Clients may only change these columns; frame/banner go through the shop RPCs.
revoke update on public.profiles from authenticated;
grant update (username, display_name, avatar_path, allow_requests, locale)
  on public.profiles to authenticated;
revoke insert, delete on public.profiles from authenticated, anon;

-- Avatars bucket: avatars/{user_id}/avatar.jpg ---------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "signed-in users read avatars"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars');

create policy "users upload their own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "users replace their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "users delete their own avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
