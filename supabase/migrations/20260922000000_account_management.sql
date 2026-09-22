-- =============================================================================
-- Everkeep — account management
--
--   * public.delete_my_account()  lets a signed-in user delete their own account
--   * `avatars` storage bucket     profile photos, one folder per user
--
-- Apply after 20260921000000_initial_schema.sql (SQL Editor or `supabase db push`).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Delete my account
--
-- A client can't delete its own row in auth.users (that needs the service role,
-- which must never be in the app). This function does it on the caller's behalf
-- and ONLY for the caller: the id comes from the JWT (auth.uid()), never from an
-- argument, so it cannot be pointed at anyone else.
--
-- Deleting the auth user cascades (ON DELETE CASCADE) to profiles,
-- security_settings, documents, accounts and trusted_contacts. Stored FILES are
-- not removed by that — Supabase must delete them through the Storage API — so
-- the app removes them first, then calls this.
-- -----------------------------------------------------------------------------

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  delete from auth.users where id = caller;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- -----------------------------------------------------------------------------
-- Avatars — public bucket, one folder per user
--
-- Public means a photo can be shown with a plain URL (fast, cacheable, no signing
-- round trip). Only the owner can add, replace, delete or LIST files in their own
-- folder. Object names look like  <user_id>/avatar.<ext>.
-- Limited to small images.
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy avatars_objects_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy avatars_objects_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy avatars_objects_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy avatars_objects_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
