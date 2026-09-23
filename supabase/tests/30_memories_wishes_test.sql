-- Verifies the memories_wishes table, its Row Level Security, and the private
-- `memories` Storage bucket by acting as two different signed-in users (and an
-- anonymous one) and checking what each can and cannot do. Every check prints
-- "ok - ..." or aborts. Runs inside a transaction that is rolled back; nothing
-- is left behind.

\set ON_ERROR_STOP on
\set alice '11111111-1111-1111-1111-111111111111'
\set bob   '22222222-2222-2222-2222-222222222222'

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  (:'alice', 'alice@example.com', '{"full_name": "Alice Anderson"}'),
  (:'bob',   'bob@example.com',   '{}');

select t.ok((select not public from storage.buckets where id = 'memories'),
            'memories bucket is private');

-- ============================ Acting as Alice ===================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);

insert into public.memories_wishes (title, content, type) values
  ('Summer at the lake', 'We spent the whole week there.', 'memory');
insert into public.memories_wishes (title, content, type, date) values
  ('For my daughter', 'Take care of the garden.', 'wish', '2026-01-01');

select t.ok((select user_id from public.memories_wishes where title = 'Summer at the lake') = :'alice',
            'user_id is filled from the signed-in user, not the client');
select t.ok((select count(*) from public.memories_wishes) = 2, 'alice sees her own memory and wish');
select t.ok((select count(*) from public.memories_wishes where type = 'memory') = 1,
            'the memory/wish split works');

select t.fails($$insert into public.memories_wishes (title, content, type) values ('x', '', 'letter')$$,
               '23514', 'a type outside memory/wish is rejected');
select t.fails($$insert into public.memories_wishes (title, content) values ('   ', '')$$,
               '23514', 'a blank title is rejected');
select t.fails(format('insert into public.memories_wishes (title, content, file_path) values (%L, %L, %L)',
                       'Stolen file', '', :'bob' || '/memories/x.jpg'),
               '23514', 'a memory cannot point at another user''s storage folder');
select t.ok(t.affected(format('insert into public.memories_wishes (title, content, file_path) values (%L, %L, %L)',
                               'With file', '', :'alice' || '/memories/x.jpg')) = 1,
            'a memory can point at the user''s own storage folder');

select t.ok(t.affected(format($q$update public.memories_wishes set content = %L where title = %L$q$,
                               'Updated.', 'Summer at the lake')) = 1,
            'alice can update her own memory');

-- storage: her own folder is allowed, anything else is not
select t.ok(t.affected(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'memories', :'alice' || '/memories/a.jpg')) = 1,
            'alice can upload into her own memories folder');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'memories', :'bob' || '/memories/a.jpg'),
               '42501', 'alice cannot upload into bob''s memories folder');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'memories', 'loose.jpg'),
               '42501', 'a memories file outside any user folder is rejected');

-- remember ids so Bob can attack them
reset role;
select id as alice_memory from public.memories_wishes where title = 'Summer at the lake' \gset
select id as alice_wish from public.memories_wishes where title = 'For my daughter' \gset
select id as alice_obj from storage.objects where name = :'alice' || '/memories/a.jpg' \gset

-- ============================= Acting as Bob ====================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'bob', 'role', 'authenticated')::text, true);

select t.ok((select count(*) from public.memories_wishes) = 0, 'bob cannot read alice''s memories or wishes');
select t.ok((select count(*) from storage.objects where bucket_id = 'memories') = 0,
            'bob cannot see alice''s stored memory files');

select t.ok(t.affected(format('update public.memories_wishes set title = %L where id = %L', 'hacked', :'alice_memory')) = 0,
            'bob cannot update alice''s memory');
select t.ok(t.affected(format('delete from public.memories_wishes where id = %L', :'alice_wish')) = 0,
            'bob cannot delete alice''s wish');
select t.ok(t.affected(format('update storage.objects set name = %L where id = %L', :'bob' || '/memories/stolen.jpg', :'alice_obj')) = 0,
            'bob cannot move alice''s memory file into his folder');
select t.ok(t.affected(format('delete from storage.objects where id = %L', :'alice_obj')) = 0,
            'bob cannot delete alice''s memory file');

select t.fails(format('insert into public.memories_wishes (user_id, title, content) values (%L, %L, %L)', :'alice', 'planted', ''),
               '42501', 'bob cannot create a memory owned by alice');

-- a legitimate change is still possible: bob works with his own data
select t.ok(t.affected($$insert into public.memories_wishes (title, content, type) values ('Bob''s wish', '', 'wish')$$) = 1,
            'bob can create his own wish');
select t.ok(t.affected($$delete from public.memories_wishes where title = 'Bob''s wish'$$) = 1,
            'bob can delete his own wish');

-- =========================== Not signed in (anon) ===============================
reset role;
set local role anon;
select set_config('request.jwt.claims', '', true);

select t.fails('select * from public.memories_wishes', '42501', 'anonymous users cannot read memories or wishes');
select t.fails($$insert into public.memories_wishes (title, content) values ('x', '')$$,
               '42501', 'anonymous users cannot write');
select t.fails(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'memories', :'alice' || '/memories/x.jpg'),
               '42501', 'anonymous users cannot upload memory files');

-- ===================== Back to Alice: her data is intact ========================
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alice', 'role', 'authenticated')::text, true);

select t.ok((select content from public.memories_wishes where id = :'alice_memory') = 'Updated.',
            'alice''s memory was not changed by bob');
select t.ok((select count(*) from public.memories_wishes where id = :'alice_wish') = 1,
            'alice''s wish survived bob''s attempts');
select t.ok((select count(*) from storage.objects where id = :'alice_obj') = 1,
            'alice''s memory file survived bob''s attempts');
select t.ok(t.affected(format('delete from public.memories_wishes where id = %L', :'alice_memory')) = 1,
            'alice can delete her own memory');
select t.ok(t.affected(format('delete from storage.objects where id = %L', :'alice_obj')) = 1,
            'alice can delete her own memory file');

-- Deleting an auth user removes everything they own (via the same ON DELETE
-- CASCADE already proven for documents/accounts/trusted_contacts) ---------------
reset role;
-- Her wish and the earlier "With file" memory are both still there.
select t.ok((select count(*) from public.memories_wishes where user_id = :'alice') = 2,
            'alice still has rows before she is deleted');
delete from auth.users where id = :'alice';
select t.ok((select count(*) from public.memories_wishes where user_id = :'alice') = 0,
            'deleting a user removes their memories and wishes too');

rollback;
