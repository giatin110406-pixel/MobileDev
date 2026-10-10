-- An empty canvas is white. Index 0 of a palette is the empty canvas colour, and the
-- 8-bit palette had a near-black there (Van Gogh a cream), so new canvases started
-- out dark.
--
-- 8-bit: white goes to index 0 and the near-black takes the place of the off-white
-- at index 3, so both black and white can still be painted. Van Gogh: index 0
-- becomes pure white.
--
-- Arrays are 1-based in Postgres, so index 0 is colors[1] and index 3 is colors[4].
-- Cells already painted with index 3 (8-bit) change from off-white to black.
update public.palettes
set colors[1] = '#FFFFFF', colors[4] = '#0F0F1B'
where id = 'eightbit' and colors[1] = '#0F0F1B' and colors[4] = '#FAFBF6';

update public.palettes
set colors[1] = '#FFFFFF'
where id = 'vangogh' and colors[1] = '#F3E9D2';
