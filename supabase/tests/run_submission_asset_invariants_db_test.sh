#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v supabase >/dev/null 2>&1; then
  printf '%s\n' 'Supabase CLI is required. Install it, then run `supabase start`.' >&2
  exit 1
fi

if ! command -v deno >/dev/null 2>&1; then
  printf '%s\n' 'Deno is required to run the database invariant tests.' >&2
  exit 1
fi

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  if ! status_environment="$(supabase status --output env)"; then
    printf '%s\n' 'Could not read the local Supabase status. Start it with `supabase start`.' >&2
    exit 1
  fi

  while IFS= read -r line; do
    case "${line}" in
      DB_URL=*)
        SUPABASE_DB_URL="${line#DB_URL=}"
        if [[ "${SUPABASE_DB_URL}" == \"*\" ]]; then
          SUPABASE_DB_URL="${SUPABASE_DB_URL#\"}"
          SUPABASE_DB_URL="${SUPABASE_DB_URL%\"}"
        fi
        break
        ;;
    esac
  done <<< "${status_environment}"
fi

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  printf '%s\n' 'No local database URL was found. Start Supabase with `supabase start`.' >&2
  exit 1
fi

export SUPABASE_DB_URL
exec deno test --allow-env --allow-net --allow-read \
  "${repository_root}/supabase/tests/submission_asset_invariants_db_test.ts"
