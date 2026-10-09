-- The `notify` Edge Function reads a few tables as the service role. This
-- project does not auto-expose new tables, so that role has no access to ours
-- until it is granted. Only what the function needs, and nothing it does not.

grant select on
  public.profiles,
  public.posts,
  public.blocks,
  public.notification_prefs
to service_role;

-- It also removes phones that Google says are gone.
grant select, delete on public.device_tokens to service_role;
