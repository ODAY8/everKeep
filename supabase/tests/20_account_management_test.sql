-- Verifies delete_my_account() and the avatars bucket.
-- Runs inside a transaction that is rolled back; nothing is left behind.

\set ON_ERROR_STOP on
\set alice '11111111-1111-1111-1111-111111111111'
\set bob   '22222222-2222-2222-2222-222222222222'

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  (:'alice', 'alice@example.com', '{"full_name": "Alice"}'),
  (:'bob',   'bob@example.com',   '{"full_name": "Bob"}');

-- Give both users some data, so we can see exactly whose disappears.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);
insert into public.documents (title) values ('Alice doc');
insert into public.accounts (name) values ('Alice acct');
insert into public.trusted_contacts (name, relationship, access_level) values ('C', 'Friend', 'View Only');

select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated')::text, true);
insert into public.documents (title) values ('Bob doc');
insert into public.accounts (name) values ('Bob acct');
reset role;

select t.ok((select public from storage.buckets where id = 'avatars'), 'avatars bucket is public (photos load by plain URL)');
select t.ok((select file_size_limit from storage.buckets where id = 'avatars') <= 2097152, 'avatars are limited to 2 MB');
select t.ok((select 'image/jpeg' = any (allowed_mime_types) and not 'application/pdf' = any (allowed_mime_types)
               from storage.buckets where id = 'avatars'), 'avatars accept images only');

-- ============================== avatars ==========================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);

select t.ok(t.affected(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'avatars', :'alice' || '/avatar.jpg')) = 1,
            'alice can upload her own avatar');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'avatars', :'bob' || '/avatar.jpg'),
               '42501', 'alice cannot upload into bob''s avatar folder');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'avatars', 'avatar.jpg'),
               '42501', 'an avatar outside a user folder is rejected');

select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated')::text, true);
select t.ok((select count(*) from storage.objects where bucket_id = 'avatars') = 0, 'bob cannot list alice''s avatar');
select t.ok(t.affected(format('delete from storage.objects where bucket_id = %L and name = %L', 'avatars', :'alice' || '/avatar.jpg')) = 0,
            'bob cannot delete alice''s avatar');

reset role;
set local role anon;
select set_config('request.jwt.claims', '', true);
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'avatars', :'alice' || '/x.jpg'),
               '42501', 'anonymous users cannot upload avatars');
reset role;

-- ========================== delete_my_account() ==================================
-- not signed in -> refused
set local role authenticated;
select set_config('request.jwt.claims', '', true);
select t.fails('select public.delete_my_account()', '28000', 'delete_my_account needs a signed-in user');

-- anonymous role may not call it at all
reset role;
set local role anon;
select t.fails('select public.delete_my_account()', '42501', 'anonymous users cannot call delete_my_account');
reset role;

-- Bob deletes himself
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated')::text, true);
select public.delete_my_account();
reset role;

select t.ok((select count(*) from auth.users where id = :'bob') = 0, 'bob''s login is gone');
select t.ok((select count(*) from public.profiles where id = :'bob') = 0, 'bob''s profile is gone');
select t.ok((select count(*) from public.security_settings where user_id = :'bob') = 0, 'bob''s settings are gone');
select t.ok((select count(*) from public.documents where user_id = :'bob') = 0, 'bob''s documents are gone');
select t.ok((select count(*) from public.accounts where user_id = :'bob') = 0, 'bob''s accounts are gone');

-- ...and only Bob
select t.ok((select count(*) from auth.users where id = :'alice') = 1, 'alice''s login is untouched');
select t.ok((select count(*) from public.documents where user_id = :'alice') = 1, 'alice''s documents are untouched');
select t.ok((select count(*) from public.accounts where user_id = :'alice') = 1, 'alice''s accounts are untouched');
select t.ok((select count(*) from public.trusted_contacts where user_id = :'alice') = 1, 'alice''s contacts are untouched');
select t.ok((select count(*) from public.profiles where id = :'alice') = 1, 'alice''s profile is untouched');

-- The function takes no arguments, so it cannot be aimed at another user: with
-- Bob gone, a call as Alice removes Alice and nobody else.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);
select public.delete_my_account();
reset role;
select t.ok((select count(*) from auth.users) = 0, 'deleting yourself removes exactly yourself');

rollback;
