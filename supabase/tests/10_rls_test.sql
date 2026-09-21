-- Verifies the schema, triggers, column privileges and Row Level Security by
-- acting as two different signed-in users (and an anonymous one) and checking
-- what each can and cannot do. Every check prints "ok - ..." or aborts.
--
-- Runs inside a transaction that is rolled back; nothing is left behind.

\set ON_ERROR_STOP on
\set alice '11111111-1111-1111-1111-111111111111'
\set bob   '22222222-2222-2222-2222-222222222222'

begin;

-- Test helpers -----------------------------------------------------------------
create schema t;
grant usage on schema t to anon, authenticated;

create function t.ok(cond boolean, msg text) returns void
language plpgsql as $$
begin
  if cond is not true then raise exception 'FAIL: %', msg; end if;
  raise notice 'ok - %', msg;
end $$;

-- Asserts that running `sql` raises an error with SQLSTATE `expected`.
create function t.fails(sql text, expected text, msg text) returns void
language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    if sqlstate = expected then
      raise notice 'ok - % (%)', msg, sqlstate;
      return;
    end if;
    raise exception 'FAIL: % — expected SQLSTATE %, got % (%)', msg, expected, sqlstate, sqlerrm;
  end;
  raise exception 'FAIL: % — statement succeeded but should have been rejected', msg;
end $$;

-- Runs `sql` and returns how many rows it affected.
create function t.affected(sql text) returns bigint
language plpgsql as $$
declare n bigint;
begin
  execute sql;
  get diagnostics n = row_count;
  return n;
end $$;

grant execute on all functions in schema t to anon, authenticated;

-- Two users sign up ---------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  (:'alice', 'alice@example.com', '{"full_name": "Alice Anderson"}'),
  (:'bob',   'bob@example.com',   '{}');

select t.ok((select full_name from public.profiles where id = :'alice') = 'Alice Anderson',
            'sign-up trigger creates a profile with the name from sign-up metadata');
select t.ok((select full_name from public.profiles where id = :'bob') = '',
            'profile is still created when no name was given');
select t.ok((select count(*) from public.security_settings) = 2,
            'sign-up trigger creates a settings row per user');
select t.ok((select not two_factor_enabled and not biometric_enabled and not login_alerts_enabled
               from public.security_settings where user_id = :'alice'),
            'new accounts do not start with security features switched on');
select t.ok((select not public from storage.buckets where id = 'documents'),
            'documents bucket is private');

-- ============================ Acting as Alice ===================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);

insert into public.documents (title, category) values ('Alice Will', 'Legal');
insert into public.accounts (name, category, username) values ('Alice Bank', 'Banking', 'alice@bank');
insert into public.trusted_contacts (name, relationship, access_level) values ('Carol', 'Sibling', 'View Only');

select t.ok((select user_id from public.documents where title = 'Alice Will') = :'alice',
            'user_id is filled from the signed-in user, not the client');
select t.ok((select count(*) from public.documents) = 1, 'alice sees her document');

select t.ok(t.affected(format('update public.profiles set phone = %L where id = %L', '555-0100', :'alice')) = 1,
            'alice can update her own profile');
select t.ok(t.affected(format('update public.security_settings set two_factor_enabled = true where user_id = %L', :'alice')) = 1,
            'alice can update her own settings');
select t.ok(t.affected(format($q$
              insert into public.security_settings (user_id, biometric_enabled) values (%L, true)
              on conflict (user_id) do update set biometric_enabled = excluded.biometric_enabled
            $q$, :'alice')) = 1,
            'alice can upsert her own settings');

select t.fails(format('insert into public.documents (title, is_verified) values (%L, true)', 'Self verified'),
               '42501', 'a client cannot create a document as verified');
select t.fails(format('update public.documents set is_verified = true where title = %L', 'Alice Will'),
               '42501', 'a client cannot mark its own document verified');
select t.fails(format('insert into public.documents (title, file_path) values (%L, %L)', 'Stolen file', :'bob' || '/documents/x.pdf'),
               '23514', 'a document cannot point at another user''s storage folder');
select t.ok(t.affected(format('insert into public.documents (title, file_path) values (%L, %L)', 'With file', :'alice' || '/documents/x.pdf')) = 1,
            'a document can point at the user''s own storage folder');
select t.fails($$insert into public.documents (title) values ('   ')$$,
               '23514', 'a blank document title is rejected');

-- storage: her own folder is allowed, anything else is not
select t.ok(t.affected(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'documents', :'alice' || '/documents/a.pdf')) = 1,
            'alice can upload into her own folder');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'documents', :'bob' || '/documents/a.pdf'),
               '42501', 'alice cannot upload into bob''s folder');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'documents', 'loose.pdf'),
               '42501', 'a file outside any user folder is rejected');

-- remember ids so Bob can attack them
reset role;
select id as alice_doc from public.documents where title = 'Alice Will' \gset
select id as alice_acc from public.accounts where name = 'Alice Bank' \gset
select id as alice_contact from public.trusted_contacts where name = 'Carol' \gset
select id as alice_obj from storage.objects where name = :'alice' || '/documents/a.pdf' \gset

-- ============================= Acting as Bob ====================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated')::text, true);

select t.ok((select count(*) from public.documents) = 0, 'bob cannot read alice''s documents');
select t.ok((select count(*) from public.accounts) = 0, 'bob cannot read alice''s accounts');
select t.ok((select count(*) from public.trusted_contacts) = 0, 'bob cannot read alice''s contacts');
select t.ok((select count(*) from storage.objects) = 0, 'bob cannot see alice''s stored files');
select t.ok((select count(*) from public.profiles) = 1
            and (select id from public.profiles) = :'bob', 'bob sees only his own profile');
select t.ok((select count(*) from public.security_settings) = 1, 'bob sees only his own settings');

select t.ok(t.affected(format('update public.documents set title = %L where id = %L', 'hacked', :'alice_doc')) = 0,
            'bob cannot update alice''s document');
select t.ok(t.affected(format('delete from public.documents where id = %L', :'alice_doc')) = 0,
            'bob cannot delete alice''s document');
select t.ok(t.affected(format('update public.accounts set is_favorite = true where id = %L', :'alice_acc')) = 0,
            'bob cannot update alice''s account');
select t.ok(t.affected(format('delete from public.accounts where id = %L', :'alice_acc')) = 0,
            'bob cannot delete alice''s account');
select t.ok(t.affected(format('update public.trusted_contacts set access_level = %L where id = %L', 'Full Access', :'alice_contact')) = 0,
            'bob cannot update alice''s contact');
select t.ok(t.affected(format('delete from public.trusted_contacts where id = %L', :'alice_contact')) = 0,
            'bob cannot delete alice''s contact');
select t.ok(t.affected(format('update public.profiles set full_name = %L where id = %L', 'hacked', :'alice')) = 0,
            'bob cannot update alice''s profile');
select t.ok(t.affected(format('update public.security_settings set two_factor_enabled = false where user_id = %L', :'alice')) = 0,
            'bob cannot change alice''s settings');
select t.ok(t.affected(format('update storage.objects set name = %L where id = %L', :'bob' || '/documents/stolen.pdf', :'alice_obj')) = 0,
            'bob cannot move alice''s file into his folder');
select t.ok(t.affected(format('delete from storage.objects where id = %L', :'alice_obj')) = 0,
            'bob cannot delete alice''s file');

select t.fails(format('insert into public.documents (user_id, title) values (%L, %L)', :'alice', 'planted'),
               '42501', 'bob cannot create a document owned by alice');
select t.fails(format('insert into public.accounts (user_id, name) values (%L, %L)', :'alice', 'planted'),
               '42501', 'bob cannot create an account owned by alice');
select t.fails(format('insert into public.trusted_contacts (user_id, name, relationship, access_level) values (%L, %L, %L, %L)', :'alice', 'x', 'x', 'x'),
               '42501', 'bob cannot create a contact owned by alice');
select t.fails(format('insert into public.profiles (id, full_name) values (%L, %L)', :'alice', 'impostor'),
               '42501', 'bob cannot write a profile for alice');
select t.fails(format('insert into public.security_settings (user_id) values (%L)', :'alice'),
               '42501', 'bob cannot write settings for alice');

-- a legitimate change is still possible: bob works with his own data
select t.ok(t.affected($$insert into public.accounts (name) values ('Bob Mail')$$) = 1, 'bob can create his own account');
select t.ok(t.affected($$update public.accounts set is_favorite = true where name = 'Bob Mail'$$) = 1, 'bob can favourite his own account');
select t.ok(t.affected($$delete from public.accounts where name = 'Bob Mail'$$) = 1, 'bob can delete his own account');

-- =========================== Not signed in (anon) ===============================
reset role;
set local role anon;
select set_config('request.jwt.claims', '', true);

select t.fails('select * from public.documents',         '42501', 'anonymous users cannot read documents');
select t.fails('select * from public.accounts',          '42501', 'anonymous users cannot read accounts');
select t.fails('select * from public.trusted_contacts',  '42501', 'anonymous users cannot read contacts');
select t.fails('select * from public.profiles',          '42501', 'anonymous users cannot read profiles');
select t.fails('select * from public.security_settings', '42501', 'anonymous users cannot read settings');
select t.fails($$insert into public.accounts (name) values ('x')$$, '42501', 'anonymous users cannot write');
select t.ok((select count(*) from storage.objects) = 0, 'anonymous users see no stored files');

-- ===================== Back to Alice: her data is intact ========================
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);

select t.ok((select title from public.documents where id = :'alice_doc') = 'Alice Will', 'alice''s document was not changed by bob');
select t.ok((select count(*) from public.accounts where id = :'alice_acc') = 1, 'alice''s account survived bob''s attempts');
select t.ok((select count(*) from public.trusted_contacts where id = :'alice_contact') = 1, 'alice''s contact survived bob''s attempts');
select t.ok((select count(*) from storage.objects where id = :'alice_obj') = 1, 'alice''s file survived bob''s attempts');
select t.ok(t.affected(format('delete from public.documents where id = %L', :'alice_doc')) = 1, 'alice can delete her own document');
select t.ok(t.affected(format('delete from storage.objects where id = %L', :'alice_obj')) = 1, 'alice can delete her own file');

-- Deleting an auth user removes everything they own ------------------------------
reset role;
delete from auth.users where id = :'bob';
select t.ok((select count(*) from public.profiles where id = :'bob') = 0
            and (select count(*) from public.security_settings where user_id = :'bob') = 0,
            'deleting a user removes their profile and settings');

rollback;
