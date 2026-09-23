-- =============================================================================
-- Everkeep — Memories & Wishes
--
-- Tables : memories_wishes
-- Storage: private `memories` bucket, one folder per user
-- Security: Row Level Security on memories_wishes and storage.objects.
--           Every policy is owner-only and keyed on auth.uid(); no user
--           can see or modify another user's memories or wishes.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- memories_wishes table
-- -----------------------------------------------------------------------------

create table if not exists public.memories_wishes (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title        text not null check (char_length(btrim(title)) between 1 and 300),
  content      text not null check (char_length(btrim(content)) <= 10000),
  type         text not null default 'memory' check (type in ('memory', 'wish')),
  date         date,
  file_path    text check (file_path is null or char_length(file_path) <= 1024),
  file_size    bigint check (file_size is null or file_size >= 0),
  mime_type    text check (mime_type is null or char_length(mime_type) <= 255),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- A file may only point at a path inside its owner's own storage folder.
  constraint memories_wishes_file_path_in_own_folder
    check (file_path is null or file_path like user_id::text || '/%')
);

create trigger memories_wishes_set_updated_at
  before update on public.memories_wishes
  for each row execute function public.set_updated_at();

-- Indexes for fast retrieval by user and by type
create index if not exists memories_wishes_user_id_idx on public.memories_wishes (user_id);
create index if not exists memories_wishes_user_type_idx on public.memories_wishes (user_id, type);

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.memories_wishes enable row level security;

create policy memories_wishes_select_own on public.memories_wishes
  for select to authenticated using ((select auth.uid()) = user_id);

create policy memories_wishes_insert_own on public.memories_wishes
  for insert to authenticated with check ((select auth.uid()) = user_id);

create policy memories_wishes_update_own on public.memories_wishes
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy memories_wishes_delete_own on public.memories_wishes
  for delete to authenticated using ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- Table privileges (defence in depth on top of RLS)
-- -----------------------------------------------------------------------------

revoke all on public.memories_wishes from anon;

revoke insert, update on public.memories_wishes from authenticated;
grant insert (title, content, type, date, file_path, file_size, mime_type)
  on public.memories_wishes to authenticated;
grant update (title, content, type, date, file_path, file_size, mime_type)
  on public.memories_wishes to authenticated;
grant select, delete on public.memories_wishes to authenticated;

-- -----------------------------------------------------------------------------
-- Storage — private `memories` bucket, one folder per user
--
-- Object names look like  <user_id>/memories/<timestamp>-<filename>.
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('memories', 'memories', false, 26214400)  -- 25 MB per file
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit;

create policy memories_objects_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy memories_objects_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy memories_objects_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy memories_objects_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'memories'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
