-- =============================================================================
-- Everkeep — initial schema
--
-- Tables : profiles, security_settings, documents, accounts, trusted_contacts
-- Storage: private `documents` bucket, one folder per user
-- Security: Row Level Security on every table and on storage.objects. Every
--           policy is owner-only and keyed on auth.uid(); there is no policy
--           that lets one authenticated user see another's rows.
--
-- Apply with the Supabase CLI (`supabase db push`) or by pasting this file into
-- the dashboard's SQL Editor (it runs as the `postgres` role).
--
-- The schema mirrors the existing Dart models. Deliberately NOT stored:
--   * email        — owned by Supabase Auth (auth.users), read from the session.
--   * secrets      — there is no password/secret column on `accounts`. Storing
--                    vault secrets needs client-side encryption with a proper
--                    key-management design first; do not add a plaintext column.
--   * icon / color — derived from an account's category in the app.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- -----------------------------------------------------------------------------
-- profiles — Everkeep's own data about a user (one row per auth user)
-- -----------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '' check (char_length(full_name) <= 200),
  phone       text check (phone is null or char_length(phone) <= 50),
  avatar_url  text check (avatar_url is null or char_length(avatar_url) <= 2048),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- security_settings — per-user preferences (one row per user)
--
-- Defaults are FALSE on purpose: a new account must not claim protections it
-- has not enabled. These are stored preferences; they do not by themselves
-- enforce 2FA or biometrics (see the security notes in the README).
-- -----------------------------------------------------------------------------

create table public.security_settings (
  user_id                uuid primary key references auth.users (id) on delete cascade,
  two_factor_enabled     boolean not null default false,
  biometric_enabled      boolean not null default false,
  login_alerts_enabled   boolean not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create trigger security_settings_set_updated_at
  before update on public.security_settings
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- documents — metadata only; file bytes live in Storage (`file_path`)
-- -----------------------------------------------------------------------------

create table public.documents (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title        text not null check (char_length(btrim(title)) between 1 and 300),
  category     text not null default 'Other' check (char_length(btrim(category)) between 1 and 100),
  description  text check (description is null or char_length(description) <= 5000),
  file_path    text check (file_path is null or char_length(file_path) <= 1024),
  file_size    bigint check (file_size is null or file_size >= 0),
  mime_type    text check (mime_type is null or char_length(mime_type) <= 255),
  -- Set by a trusted process, never by the client (see column privileges below).
  is_verified  boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- A document may only point at a file inside its owner's own storage folder.
  constraint documents_file_path_in_own_folder
    check (file_path is null or file_path like user_id::text || '/%')
);

create index documents_user_id_created_at_idx
  on public.documents (user_id, created_at desc);

create trigger documents_set_updated_at
  before update on public.documents
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- accounts — a saved login (no secret is stored here; see header note)
-- -----------------------------------------------------------------------------

create table public.accounts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name         text not null check (char_length(btrim(name)) between 1 and 300),
  username     text check (username is null or char_length(username) <= 300),
  category     text not null default 'Other' check (char_length(btrim(category)) between 1 and 100),
  is_favorite  boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index accounts_user_id_created_at_idx
  on public.accounts (user_id, created_at desc);

create trigger accounts_set_updated_at
  before update on public.accounts
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- trusted_contacts
-- -----------------------------------------------------------------------------

create table public.trusted_contacts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name          text not null check (char_length(btrim(name)) between 1 and 200),
  relationship  text not null check (char_length(btrim(relationship)) between 1 and 200),
  access_level  text not null check (char_length(btrim(access_level)) between 1 and 100),
  avatar_url    text check (avatar_url is null or char_length(avatar_url) <= 2048),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index trusted_contacts_user_id_created_at_idx
  on public.trusted_contacts (user_id, created_at);

create trigger trusted_contacts_set_updated_at
  before update on public.trusted_contacts
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- New user -> profile + default settings
--
-- Runs inside the sign-up transaction, so it works even when the address still
-- has to be confirmed and the client has no session yet. The name comes from
-- the `full_name` the app sends as sign-up metadata.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'full_name', ''), 200));

  insert into public.security_settings (user_id)
  values (new.id);

  return new;
end;
$$;

-- Only the trigger should run this; nobody can call it directly.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- -----------------------------------------------------------------------------
-- Row Level Security — owner only, per operation
--
-- `(select auth.uid())` (rather than a bare auth.uid()) lets Postgres evaluate
-- it once per statement instead of once per row.
-- -----------------------------------------------------------------------------

alter table public.profiles          enable row level security;
alter table public.security_settings enable row level security;
alter table public.documents         enable row level security;
alter table public.accounts          enable row level security;
alter table public.trusted_contacts  enable row level security;

-- profiles (keyed on id). No DELETE policy: a profile disappears only when its
-- auth user is deleted (ON DELETE CASCADE); the app never deletes it directly.
create policy profiles_select_own on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- security_settings
create policy security_settings_select_own on public.security_settings
  for select to authenticated using ((select auth.uid()) = user_id);
create policy security_settings_insert_own on public.security_settings
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy security_settings_update_own on public.security_settings
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy security_settings_delete_own on public.security_settings
  for delete to authenticated using ((select auth.uid()) = user_id);

-- documents
create policy documents_select_own on public.documents
  for select to authenticated using ((select auth.uid()) = user_id);
create policy documents_insert_own on public.documents
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy documents_update_own on public.documents
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy documents_delete_own on public.documents
  for delete to authenticated using ((select auth.uid()) = user_id);

-- accounts
create policy accounts_select_own on public.accounts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy accounts_insert_own on public.accounts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy accounts_update_own on public.accounts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy accounts_delete_own on public.accounts
  for delete to authenticated using ((select auth.uid()) = user_id);

-- trusted_contacts
create policy trusted_contacts_select_own on public.trusted_contacts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy trusted_contacts_insert_own on public.trusted_contacts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy trusted_contacts_update_own on public.trusted_contacts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy trusted_contacts_delete_own on public.trusted_contacts
  for delete to authenticated using ((select auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- Table privileges (defence in depth on top of RLS)
--
-- Supabase grants API roles broad access by default and leaves RLS to do the
-- gating. Signed-out (anon) requests get no access to these tables at all.
-- -----------------------------------------------------------------------------

revoke all on public.profiles, public.security_settings, public.documents,
              public.accounts, public.trusted_contacts
  from anon;

-- Clients may not choose `is_verified`, or reassign a row to another user via
-- user_id: only the listed columns can be written. (user_id fills itself in
-- from auth.uid(); RLS then checks it.)
revoke insert, update on public.documents from authenticated;
grant insert (title, category, description, file_path, file_size, mime_type)
  on public.documents to authenticated;
grant update (title, category, description, file_path, file_size, mime_type)
  on public.documents to authenticated;


-- -----------------------------------------------------------------------------
-- Storage — private bucket, one folder per user
--
-- Object names look like  <user_id>/documents/<...>.  The policies below only
-- allow a user to touch objects whose first folder is their own user id.
-- The bucket is NOT public: files are only reachable by their owner, or through
-- short-lived signed URLs that the owner creates.
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 26214400)  -- 25 MB per file
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit;

create policy documents_objects_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy documents_objects_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy documents_objects_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy documents_objects_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
