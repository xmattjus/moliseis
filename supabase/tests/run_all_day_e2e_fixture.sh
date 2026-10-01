#!/usr/bin/env bash
set -euo pipefail
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
status_environment="$(cd "$repository_root" && supabase status --output env < /dev/null)"
while IFS= read -r line; do
  case "$line" in
    API_URL=*|SERVICE_ROLE_KEY=*|DB_URL=*)
      key="${line%%=*}"
      value="${line#*=}"
      value="${value#\"}"
      value="${value%\"}"
      if [[ "$key" == DB_URL ]]; then key=SUPABASE_DB_URL; fi
      export "$key=$value"
      ;;
  esac
done <<< "$status_environment"
exec deno run --allow-env --allow-net "$repository_root/supabase/tests/all_day_e2e_fixture.ts"
