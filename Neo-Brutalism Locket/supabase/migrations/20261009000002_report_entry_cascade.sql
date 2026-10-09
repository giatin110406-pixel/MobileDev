-- A report about an entry means nothing once the entry is gone. With "on delete set
-- null" the report row would have no target left and break reports_has_target, which
-- made it impossible to delete an entry that had been reported.

alter table public.reports drop constraint reports_target_entry_fkey;
alter table public.reports
  add constraint reports_target_entry_fkey
  foreign key (target_entry) references public.contest_entries (id) on delete cascade;
