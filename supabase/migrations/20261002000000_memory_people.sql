-- =============================================================================
-- EverKeep — People Tagging in Memories
--
-- Tables  : people, memory_people
-- Supports: Manually tagging people in memories and wishes
-- Security: Strict Row Level Security on both tables (isolated to auth.uid())
-- Cascade : Deleting a user deletes their people and memory associations;
--           deleting a memory deletes its memory_people links;
--           deleting a person deletes their memory_people links.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. public.people
-- -----------------------------------------------------------------------------

create table if not exists public.people (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null check (char_length(btrim(name)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger for automated updated_at timestamping
create trigger people_set_updated_at
  before update on public.people
  for each row execute function public.set_updated_at();

-- Indexes for user lookups and case-insensitive unique names per user
create index if not exists people_user_id_idx
  on public.people (user_id);

create unique index if not exists people_user_lower_name_idx
  on public.people (user_id, lower(btrim(name)));

-- -----------------------------------------------------------------------------
-- 2. public.memory_people (Join Table)
-- -----------------------------------------------------------------------------

create table if not exists public.memory_people (
  id         uuid primary key default gen_random_uuid(),
  memory_id  uuid not null references public.memories_wishes(id) on delete cascade,
  person_id  uuid not null references public.people(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),

  -- Prevent duplicate person tagging on the same memory
  constraint memory_people_memory_person_unique
    unique (memory_id, person_id)
);

-- Indexes for fast bi-directional lookups and RLS enforcement
create index if not exists memory_people_memory_idx
  on public.memory_people (memory_id);

create index if not exists memory_people_person_idx
  on public.memory_people (person_id);

create index if not exists memory_people_user_idx
  on public.memory_people (user_id);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security — public.people
-- -----------------------------------------------------------------------------

alter table public.people enable row level security;

create policy people_select_own on public.people
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy people_insert_own on public.people
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy people_update_own on public.people
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy people_delete_own on public.people
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 4. Row Level Security — public.memory_people
-- -----------------------------------------------------------------------------

alter table public.memory_people enable row level security;

create policy memory_people_select_own on public.memory_people
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy memory_people_insert_own on public.memory_people
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.memories_wishes
      where id = memory_id and user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.people
      where id = person_id and user_id = (select auth.uid())
    )
  );

create policy memory_people_delete_own on public.memory_people
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 5. Table Privileges (Defense in Depth)
-- -----------------------------------------------------------------------------

revoke all on public.people from anon;
revoke all on public.memory_people from anon;

grant select, insert, update, delete on public.people to authenticated;
grant select, insert, delete on public.memory_people to authenticated;
