-- =============================================================================
-- EverKeep — Memory Date & Timeline Indexes
--
-- Adds composite indexes for efficient memory date and timeline sorting
-- under user_id RLS.
-- =============================================================================

create index if not exists memories_wishes_user_date_idx
  on public.memories_wishes (user_id, date desc nulls last);

create index if not exists memories_wishes_user_created_at_idx
  on public.memories_wishes (user_id, created_at desc);
