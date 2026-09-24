-- =============================================================================
-- EverKeep — Memory Tags & Location
--
-- Adds optional `tags` and `location` columns to `public.memories_wishes`
-- =============================================================================

alter table public.memories_wishes
  add column if not exists tags text,
  add column if not exists location text;

grant insert (tags, location) on public.memories_wishes to authenticated;
grant update (tags, location) on public.memories_wishes to authenticated;
