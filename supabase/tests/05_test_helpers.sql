-- Shared assertion helpers for the database tests (schema `t`). Persistent, so every
-- test file can use them; run.sh loads this once before the tests.

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
