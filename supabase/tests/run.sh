#!/usr/bin/env bash
# Applies the migration to a throwaway Postgres (Docker) and runs the RLS tests.
#
#   bash supabase/tests/run.sh
#
# Uses a small stand-in for Supabase's auth/storage schemas (00_supabase_stub.sql),
# so this checks the policies' logic. It does not replace testing against your
# real Supabase project.
set -euo pipefail

cd "$(dirname "$0")/../.."

NAME=everkeep-rls-test
IMAGE="${POSTGRES_IMAGE:-postgres:16-alpine}"

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -e POSTGRES_PASSWORD=test "$IMAGE" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT

# The image restarts Postgres once while initialising; wait until it stays up.
for _ in $(seq 1 60); do
  docker exec "$NAME" psql -U postgres -tAc 'select 1' >/dev/null 2>&1 && break
  sleep 1
done
sleep 2

run() {
  echo "==> $1"
  docker exec -i "$NAME" psql -U postgres -v ON_ERROR_STOP=1 -q < "$1"
}

run supabase/tests/00_supabase_stub.sql
for migration in supabase/migrations/*.sql; do run "$migration"; done
run supabase/tests/05_test_helpers.sql
for t in supabase/tests/10_rls_test.sql supabase/tests/20_account_management_test.sql supabase/tests/30_memories_wishes_test.sql; do run "$t" 2>&1 | grep -E "^(psql:.*)?(NOTICE|ERROR)|FAIL|ok - " | sed -E "s/^psql:[^ ]+ NOTICE:  //"; done
echo "All database checks passed."
