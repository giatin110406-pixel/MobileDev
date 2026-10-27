-- Any group may enter the weekly contest, whatever its size and however little of
-- its canvas is painted: a group of one (just its owner) is enough, and so is an
-- empty canvas. The rest of submitting stays as it was (only the owner submits,
-- once per group, 100 entries at most).
--
-- To bring the old rules back:
--   update public.contest_config set value = '2' where key = 'min_group_size';
--   update public.contest_config set value = '10' where key = 'min_fill_percent';

update public.contest_config set value = '1' where key = 'min_group_size';
update public.contest_config set value = '0' where key = 'min_fill_percent';
