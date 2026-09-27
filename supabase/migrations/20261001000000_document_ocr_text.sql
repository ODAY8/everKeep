-- =============================================================================
-- EverKeep — OCR Extracted Text for Documents
--
-- Adds optional `ocr_text` column to `public.documents` to store searchable,
-- user-editable extracted text from scanned images and PDFs.
--
-- Security:
--   * Row Level Security (RLS) policies on public.documents automatically apply.
--   * OCR text belongs strictly to the authenticated document owner.
--   * No public storage or service_role access.
-- =============================================================================

alter table public.documents
  add column if not exists ocr_text text check (ocr_text is null or char_length(ocr_text) <= 50000);

-- Grant column permissions to authenticated users
grant insert (ocr_text) on public.documents to authenticated;
grant update (ocr_text) on public.documents to authenticated;
