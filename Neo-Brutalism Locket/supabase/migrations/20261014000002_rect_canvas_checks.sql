-- The table of canvases still demanded a square of 16, 24 or 32 cells (two CHECKs from
-- the first canvas migration), so a 40 x 16 canvas was refused. A canvas may now be
-- any rectangle between 8 and 64 cells on each side. Existing canvases are all
-- inside that, so nothing changes for them. (`octet_length(pixels) = width * height`
-- stays.)
alter table public.canvases
  drop constraint canvases_check,
  drop constraint canvases_width_check;

alter table public.canvases
  add constraint canvases_size_check
  check (width between 8 and 64 and height between 8 and 64);
