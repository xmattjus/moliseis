#!/usr/bin/env bash
set -euo pipefail
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# A separate local Supabase Postgres container bootstraps the actual platform
# schemas and replays unchanged historical migrations; no linked DB is used.
upgrade_root="$(mktemp -d "${TMPDIR:-/tmp}/canonical-sync-upgrade.XXXXXX")"
cleanup() {
  local test_status=$?
  if ! supabase stop --workdir "$upgrade_root" --no-backup > "$upgrade_root/stop.log" 2>&1; then
    printf '%s\n' 'Could not clean the disposable canonical sync upgrade database.' >&2
    test_status=1
  fi
  rm -rf "$upgrade_root"
  exit "$test_status"
}
trap cleanup EXIT
mkdir -p "$upgrade_root/supabase/migrations"
cp "$repository_root/supabase/config.toml" "$upgrade_root/supabase/config.toml"
python3 - "$upgrade_root/supabase/config.toml" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text().replace('project_id = "moliseis_v2"', 'project_id = "canonical_sync_upgrade"')
for old, new in [(54320,55430),(54321,55431),(54322,55432),(54323,55433),(54324,55434),(54327,55437),(54329,55439)]:
    text = text.replace(f'port = {old}', f'port = {new}')
path.write_text(text)
PY
for migration in "$repository_root"/supabase/migrations/*.sql; do
  if [[ "$(basename "$migration")" < "20261012165537_optimize_content_sync_delta_retrieval.sql" ]]; then
    cp "$migration" "$upgrade_root/supabase/migrations/"
  fi
done
if ! supabase db start --workdir "$upgrade_root" > "$upgrade_root/start.log" 2>&1; then
  cat "$upgrade_root/start.log" >&2
  exit 1
fi
export SUPABASE_DB_URL='postgresql://postgres:postgres@127.0.0.1:55432/postgres'
exec_status=0
deno test --allow-env --allow-net --allow-read \
  "$repository_root/supabase/tests/canonical_content_sync_migration_db_test.ts" || exec_status=$?
exit "$exec_status"
