-- =============================================================================
-- Everkeep — Password Vault extensions for accounts
--
-- Adds optional columns for website, notes, and encrypted_password to
-- the existing public.accounts table.
--
-- Security:
--   * Passwords are encrypted client-side on-device before transmission.
--   * Plaintext passwords, master keys, and encryption secrets are NEVER stored in Supabase.
--   * Strict RLS policies already present on public.accounts automatically apply.
-- =============================================================================

alter table public.accounts
  add column if not exists website text check (website is null or char_length(website) <= 2048),
  add column if not exists notes text check (notes is null or char_length(notes) <= 5000),
  add column if not exists encrypted_password text check (encrypted_password is null or char_length(encrypted_password) <= 4096);
