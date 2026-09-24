-- =============================================================================
-- EverKeep — Structured Document Vault Metadata
--
-- Adds structured metadata fields to `public.documents`:
-- - `document_type`: structured taxonomy (e.g. passport, national_id, etc.)
-- - `document_number`: optional document/policy/identifier number
-- - `country`: optional country of issuance/origin
-- - `institution`: optional issuing authority, university, company or provider
-- - `notes`: optional user notes and context
-- =============================================================================

alter table public.documents
  add column if not exists document_type text,
  add column if not exists document_number text,
  add column if not exists country text,
  add column if not exists institution text,
  add column if not exists notes text;

-- Grant column permissions to authenticated users
grant insert (document_type, document_number, country, institution, notes) on public.documents to authenticated;
grant update (document_type, document_number, country, institution, notes) on public.documents to authenticated;

-- Helpful indexes for querying and sorting documents
create index if not exists documents_user_id_doc_type_idx
  on public.documents (user_id, document_type);

create index if not exists documents_user_id_country_idx
  on public.documents (user_id, country);
