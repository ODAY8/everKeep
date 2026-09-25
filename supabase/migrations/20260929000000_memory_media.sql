-- =============================================================================
-- EverKeep — Memory Media (Rich Media Architecture)
--
-- Table   : memory_media
-- Supports: Multiple photos, videos, and voice recordings per memory
-- Security: Row Level Security on memory_media (isolated to auth.uid())
-- Cascade : Memory deletion automatically removes all child media rows
-- =============================================================================

create table if not exists public.memory_media (
  id               uuid primary key default gen_random_uuid(),
  memory_id        uuid not null references public.memories_wishes(id) on delete cascade,
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  file_path        text not null check (char_length(file_path) <= 1024),
  media_type       text not null check (media_type in ('photo', 'video', 'audio')),
  mime_type        text not null check (char_length(mime_type) <= 255),
  file_size        bigint not null check (file_size >= 0),
  display_order    integer not null default 0 check (display_order >= 0),
  caption          text check (caption is null or char_length(btrim(caption)) <= 500),
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  thumbnail_path   text check (thumbnail_path is null or char_length(thumbnail_path) <= 1024),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  -- Security constraint: file_path must point inside owner's own storage folder
  constraint memory_media_file_path_in_own_folder
    check (file_path like user_id::text || '/%')
);

-- Trigger for automated updated_at timestamping
create trigger memory_media_set_updated_at
  before update on public.memory_media
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Indexes for ordered memory retrieval and user-isolated RLS lookups
-- -----------------------------------------------------------------------------

create index if not exists memory_media_memory_order_idx
  on public.memory_media (memory_id, display_order asc);

create index if not exists memory_media_user_idx
  on public.memory_media (user_id);

create index if not exists memory_media_type_idx
  on public.memory_media (memory_id, media_type);

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.memory_media enable row level security;

create policy memory_media_select_own on public.memory_media
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy memory_media_insert_own on public.memory_media
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.memories_wishes
      where id = memory_id and user_id = (select auth.uid())
    )
  );

create policy memory_media_update_own on public.memory_media
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy memory_media_delete_own on public.memory_media
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- Table privileges
-- -----------------------------------------------------------------------------

revoke all on public.memory_media from anon;
grant select, insert, update, delete on public.memory_media to authenticated;
