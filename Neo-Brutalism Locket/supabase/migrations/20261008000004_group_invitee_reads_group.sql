-- A person who has been invited is not a member yet, so the members-only policy
-- hides the group from them. Let them read the group (name, avatar, rules) while
-- their invite is still open, so the invite screen can say what they are joining.

create policy "invitees read the group they were invited to"
  on public.groups for select to authenticated
  using (
    dissolved_at is null
    and exists (
      select 1 from public.group_invites i
      where i.group_id = groups.id
        and i.invitee_id = (select auth.uid())
        and i.status = 'pending'
        and i.expires_at > now()
    )
  );
