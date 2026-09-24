-- =============================================================================
-- EverKeep — Document Expiration & Attention
--
-- Adds `issue_date` and `expiry_date` columns to `public.documents` to enable
-- the Document Attention System ("Passport expires in 87 days", etc.).
-- =============================================================================

alter table public.documents
  add column if not exists issue_date date,
  add column if not exists expiry_date date;

-- Grant permissions for authenticated users on new columns
grant insert (issue_date, expiry_date) on public.documents to authenticated;
grant update (issue_date, expiry_date) on public.documents to authenticated;

-- Index for querying documents by expiration
create index if not exists documents_user_id_expiry_date_idx
  on public.documents (user_id, expiry_date);
