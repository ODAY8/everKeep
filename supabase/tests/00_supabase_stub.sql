-- Minimal stand-in for the parts of Supabase that the migration depends on, so
-- the schema and its Row Level Security can be tested on a plain Postgres
-- (see run.sh). NOT for a real Supabase project — it already has all of this.

create role anon nologin;
create role authenticated nologin;

create schema auth;
create schema storage;

grant usage on schema public, auth, storage to anon, authenticated;

-- Supabase grants the API roles broad table access by default and relies on
-- RLS (plus the migration's explicit revokes) to gate it. Mimic that.
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema storage grant all on tables to anon, authenticated;

create table auth.users (
  id                  uuid primary key default gen_random_uuid(),
  email               text,
  raw_user_meta_data  jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now()
);

-- Same logic as Supabase's auth.uid(): the `sub` claim of the request's JWT.
create function auth.uid() returns uuid
language sql stable as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    ),
    ''
  )::uuid
$$;

create table storage.buckets (
  id                 text primary key,
  name               text not null,
  owner              uuid,
  public             boolean default false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);

create table storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text references storage.buckets (id),
  name       text,
  owner      uuid default auth.uid(),
  created_at timestamptz default now(),
  metadata   jsonb
);
alter table storage.objects enable row level security;

-- Same as Supabase's storage.foldername(): every path segment except the file.
create function storage.foldername(name text) returns text[]
language plpgsql as $$
declare _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end
$$;
