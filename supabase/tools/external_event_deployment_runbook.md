# EventiMolise provenance release runbook

Production rollout completed on **2026-10-03**, with subsequent manual smoke/E2E
reported in the
[archived final production evidence](../../openspec/changes/archive/2026-10-03-add-external-event-provenance-moderation/implementation-verification.md#production-rollout--2026-10-03-and-subsequent-smokee2e).
The earlier local rehearsals and `NOT_EXECUTED` entries are historical evidence
from before production authorization; they do not themselves certify production
gates. Execute production commands only under a separately authorized release.
Keep exports, source captures, job configuration, release manifests, and
invocation evidence in private operator storage. Never print credentials, Vault
values, HTTP authorization headers, or request headers/bodies to an evidence
log.

The scheduler names are distinct:

- **Legacy cron job:** `import-external-events-eventimolise`.
- **Provenance cron job:** `import-external-events-eventimolise-provenance`.

The provenance cron is operator-managed and intentionally not created by schema
migrations. The post-cutover
[forward retirement migration](../migrations/20261003225355_retire_legacy_external_event_cron.sql)
removes the legacy job if present; complete fresh migration replay leaves **both
names absent**. Replay therefore cannot reactivate the legacy schedule and does
not authorize provenance activation. The staged prefixes below describe the
original ordered rollout; the retirement follow-up does not create a scheduler
or deploy an Edge Function.

The required order is:

1. Additive schema, DB guards, notification compatibility.
2. Compatible Admin Edge/backend.
3. Updated Admin Flutter client available to moderators.
4. Legacy writer freeze, queued/in-flight drain, verified quiescence, T0.
5. Identity audit, shadow normalization, classification, remediation.
6. Verified backfill and final gates.
7. Explicit provenance cut-over and permanent legacy writer retirement.
8. Provenance-aware importer activation before the next Europe/Rome midnight.

Do not create production update-mode pending proposals, including
backfill-created proposals, before step 3. `PROMOTION_SOURCE_ALREADY_LINKED` on
an old client proves integrity protection, not a complete moderation rollout.

## 1. Prepare and release the additive prefix

Review the current remote migration history and the release checkout. The CLI
has no migration stop-version option. Prepare a temporary workdir containing the
reviewed config and **all historical migrations up to the exact prefix**, and
review its dry-run. Do not push the full implementation checkout at step 1.

```bash
set -euo pipefail
: "${release_project_ref:?set the authorized project reference}"
release_stage_dir="$(mktemp -d)"
mkdir -p "$release_stage_dir/supabase/migrations"
cp supabase/config.toml "$release_stage_dir/supabase/config.toml"
release_prefix=20261002175147
for migration in supabase/migrations/*.sql; do
  filename="${migration##*/}"
  version="${filename%%_*}"
  if [[ "$version" < "$release_prefix" || "$version" == "$release_prefix" ]]; then
    cp "$migration" "$release_stage_dir/supabase/migrations/"
  fi
done
supabase db push --dry-run --skip-vault --project-ref "$release_project_ref" --workdir "$release_stage_dir"
# After reviewing the exact pending list, under production release authorization:
supabase db push --skip-vault --project-ref "$release_project_ref" --workdir "$release_stage_dir"
supabase functions deploy notify-submission-status --project-ref "$release_project_ref"
```

This prefix includes M1 schema/consistency guards and structural DB notification
suppression, M2 ingestion primitives, and M3 Reject/un-ignore primitives. The
scheduler and deployed legacy importer remain unchanged. Deploy the compatible
notification Edge selection/parser/suppression before any verified backfill.
Keep its existing `verify_jwt = false` configuration; retain the existing
webhook secret validation. Verify human notifications still work and
structurally external submissions cannot claim/send contributor mail. Record
migration and notification build/probe references.

## 2. Release the compatible Admin backend, then resolution RPCs

Deploy `admin-content-submissions` **before** the M4 promotion RPC can emit its
new already-linked outcome. Retain `verify_jwt = true` and verified Admin JWT
actor ownership. Do not deploy all functions or use `--no-verify-jwt`.

```bash
supabase functions deploy admin-content-submissions --project-ref "$release_project_ref"
```

On a human pending fixture, verify ordinary load/Save/Reject/Promote
compatibility with the old RPC signature. The ordinary Promote request omits
absent optional acknowledgement arguments; it remains compatible until M4 is
installed. Verify the released handler maps `source_already_linked` to
`PROMOTION_SOURCE_ALREADY_LINKED`/409 before releasing that producer. Record its
build and mapping test evidence.

Recreate the temporary migration workdir using step 1's loop, now with
`release_prefix=20261002201857`, review the dry-run, then push only that prefix.
This adds M4 resolution/Save guards and M7 asset claim. Verify service-role
ACLs, imported direct status/link denial, Event-only Link/Save/Apply, opaque
tokens, already-resolved retries, Reject acknowledgement, and source asset
claim. Do not activate the provenance importer yet.

## 3. Release the updated client and prove it is usable

Build/release the reviewed Flutter Admin client using the established deployment
procedure. Record the released version and actual moderator availability. Probe
these paths against the compatible released backend, using isolated fixtures:
update-mode Link and Apply; Reject with ignore; ignored-record list and
un-ignore; stale indicator; explicit current-source acknowledgement;
`source_changed` feedback; exact opaque preview-token round trip. Clean up the
fixtures.

Store the proof references using the existing backfill manifest's
`release_gates.additive_schema_notifications`, `compatible_admin_backend`, and
`updated_admin_client` keys, plus `updated_client_probe_refs` with keys
`update_link`, `update_apply`, `reject_ignore`, `ignored_records_unignore`,
`stale_indicator`, `current_source_acknowledgement`, `source_changed`, and
`opaque_preview_tokens`. The following read-only preflight **must succeed before
any freeze**:

```bash
deno run --allow-read supabase/tools/external_event_rollout_preflight.ts "$private_release_evidence"
```

The preflight checks evidence completeness, not a live deployment or truth of an
operator assertion. The reviewer must verify the references themselves.

## 4. Withdraw the legacy writer, drain it, then record T0

Before withdrawal, preserve the exact deployed legacy bundle (including its
shared dependencies), deployed version, named cron definition and configuration
in private storage. A downloaded bundle must be verified as a reproducible
unchanged restore candidate **before** freeze; downloading the new checkout is
not a legacy backup.

```bash
supabase functions download import-external-events --project-ref "$release_project_ref" --workdir "$private_legacy_backup"
```

Through the authorized database operator connection, disable only the named job:

```sql
select cron.unschedule(jobid)
from cron.job
where jobname = 'import-external-events-eventimolise';
```

Withdraw the public/manual invocation route as well. Unscheduling alone does not
stop queued HTTP requests or manual callers:

```bash
supabase functions delete import-external-events --project-ref "$release_project_ref"
```

Deletion prevents new dispatches reaching this route; it is not proof that an
already-running invocation has stopped. Stop/drain any separately configured
manual caller. Record all pre-withdrawal and late queued/in-flight invocation
identifiers and terminal outcomes. Inspect the named job's run records and
`net._http_response` for the saved request IDs without exposing request
headers/bodies. For example:

```sql
select jobid, jobname, schedule, active from cron.job
where jobname = 'import-external-events-eventimolise';
select runid, status, start_time, end_time from cron.job_run_details
where jobid = :saved_legacy_job_id order by runid desc;
select id, status_code, timed_out from net._http_response
where id = any(:saved_legacy_request_ids);
```

Correlate these with Edge invocation logs and completed source-fetch/write
attempts. An HTTP timeout, an empty queue, a quiet interval, or schedule removal
alone is **not** a writer-quiescence proof. A late legacy request already inside
the handler must finish before T0. A late request after route withdrawal must be
rejected. If any invocation remains unaccounted for, stop; do not record T0.

Only after verified quiescence, record one raw timestamp and its Rome date:

```sql
with boundary as (select clock_timestamp() as t0)
select t0::text, (t0 at time zone 'Europe/Rome')::date::text as rome_date
from boundary;
```

Keep the writer withdrawn throughout steps 5–8. Bind all evidence and release
gates to this T0 and reviewed frozen population. The whole window must finish
within this Europe/Rome calendar date.

## 5. Export, audit, shadow, classify and remediate

Follow [the migration tooling README](README.md). Export the complete legacy
UUID population through `export_external_event_history.sql`; SQL JSONB is the
comparison boundary, avoiding driver timestamp truncation and PostgREST floating
point serialization differences. Notes identify sources only, not historical
snapshots or image-attempt evidence.

Use the production `discoverFutureStartDates`/`fetchEventsForDate` adapter for
current observations. Save discovery and raw HTTP-response evidence privately.
Discovery has a bounded page count: independently verify the final fetched page
has no unvisited next-page link. A page-cap/loop truncation, partial export,
invalid provider row (`invalidCount > 0`), failed fetch or unresolved source ID
blocks the audit; it does not prove source disappearance. A verified absence
requires its own current availability/discovery evidence reference. Do not infer
original historical snapshots from moderated submission content.

Run the readonly audit and plan commands from the README. Review every identity,
all seven closed classifications, captures, mismatch explanations and required
remediation/authorization. Preserve unverifiable historical rows as legacy; only
`verified_unhandled` may have a null proposed watermark. Do not authorize a real
accepted drift as an incidental baseline. Record total population coverage, zero
unresolved identity/shadow/source failures and reviewer references.

## 6. Dry-run real RPCs, verified backfill and final gates

Use `migrate_external_events.ts --plan` for structured diagnostics, then its
rollback-only `--dry-run`. The dry-run uses actual ingestion predicates and
requires every pending proposal to have an exact identity/hash explanation. No
arbitrary percentage threshold bypasses unexplained proposals. The CLI defaults
to `--plan`; only explicit `--apply` commits.

Require the reviewed schema/backend/client, freeze, queued/in-flight drain,
quiescence, T0 and manifest references before apply. Read connection/ingest
identity from private env (`MIGRATION_DB_URL`,
`EXTERNAL_EVENTS_IMPORTER_USER_ID`); never put them in a manifest or log. Use
the README's explicit invocation. The tool rechecks the original T0 date after
its dry-run and immediately before committing the backfill transaction; a
midnight crossing rolls back. Validate final counts, constraints, snapshots,
conservative legacy media budgets and exactly explained proposals. Fill the
production report from actual evidence, not the fixture report. A new attempt
starts as `NOT_EXECUTED`; the completed 2026-10-03 rollout is recorded
separately in the archived final production evidence linked above.

## 7. Declare the point of no return

After the verified backfill/final gates and a fresh same-Rome-date check, record
an explicit operator-approved provenance cut-over timestamp, release hash and
evidence reference. Mark the legacy writer permanently retired. Preserve its
backup for audit, but remove it from eligible deployment/cron restore
candidates. After this boundary, **never redeploy or reschedule the legacy
writer**, including rollback, expiry, importer failure or a later normalization
migration.

## 8. Activate only the provenance-aware importer

Check the original T0 Rome date again immediately before activation. Deploy only
the reviewed new importer bundle, preserving its existing cron-secret boundary:

```bash
supabase functions deploy import-external-events --project-ref "$release_project_ref"
```

Verify env configuration through private operator tooling. The configured
`EXTERNAL_EVENTS_IMPORTER_USER_ID` goes only to ingest; the source image URL
stays in Edge orchestration, never the claim RPC. Preserve `verify_jwt = false`;
the Edge authenticates `x-import-secret`, and all source writes go through
`ingest_external_event`.

Through the authorized database operator connection, explicitly create or update
`import-external-events-eventimolise-provenance` with this reviewed definition.
Execute as the privileged scheduling database role with visibility of all jobs.
The named scheduling primitive identifies jobs by name and scheduling role;
rerunning activation as the same role updates that job. If a provenance job
already belongs to a different role, the guard fails closed instead of creating
a second same-name schedule. The legacy-job precondition likewise fails closed
instead of leaving both names active. Do not print the resolved Vault secrets or
replace this with an unprotected invocation.

```sql
begin;

do $$
begin
  if exists (
    select 1 from cron.job
    where jobname = 'import-external-events-eventimolise'
  ) then
    raise exception 'Retire the legacy EventiMolise cron before provenance activation';
  end if;
  if exists (
    select 1 from cron.job
    where jobname = 'import-external-events-eventimolise-provenance'
      and username <> current_user
  ) then
    raise exception 'Use the existing provenance cron scheduling role before activation';
  end if;
end;
$$;

select cron.schedule_in_database(
  'import-external-events-eventimolise-provenance',
  '0 22,23 * * *',
  $provenance_command$
    select net.http_post(
      url := (
        select decrypted_secret from vault.decrypted_secrets
        where name = 'import_external_events_function_url'
        limit 1
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-import-secret', (
          select decrypted_secret from vault.decrypted_secrets
          where name = 'import_external_events_cron_secret'
          limit 1
        )
      ),
      body := jsonb_build_object(
        'source', 'eventimolise',
        'dry_run', false,
        'limit', 20,
        'mode', 'scheduled'
      ),
      timeout_milliseconds := 120000
    ) as request_id;
  $provenance_command$,
  'postgres',
  null,
  true
);

select jobid, jobname, schedule, active
from cron.job
where jobname in (
  'import-external-events-eventimolise',
  'import-external-events-eventimolise-provenance'
);

commit;
```

The schedule has two UTC windows to cover Europe/Rome DST. With
`mode = scheduled`, the Edge accepts only the invocation falling at 00:xx
Europe/Rome; the other window does not ingest. Verify exactly one active
`import-external-events-eventimolise-provenance` job with `0 22,23 * * *`, no
`import-external-events-eventimolise` job, and no separately scheduled legacy
bundle. Record activation within T0's Rome date and the ordinary smoke-run
result.

## Abandonment and rollback

**Before cut-over only (historical initial-rollout option):** this branch is no
longer available for the completed 2026-10-03 cutover. If the date changes
during an attempt still before its cut-over, abandon the attempt,
invalidate/discard its audit snapshot and manifest as release inputs, and start
a later attempt from a fresh freeze/quiescence/T0. The default is to remain
frozen. Optionally restore only the verified unchanged legacy bundle and saved
legacy `import-external-events-eventimolise` schedule before cut-over only,
after review proves the current persisted state is compatible. A committed
backfill is not automatically undone; if it has committed and release stops,
keep the writer disabled pending review. Do not invent a destructive data
rollback or silently reuse expired evidence.

**After cut-over:** stop explicitly
`import-external-events-eventimolise-provenance` and withdraw the
provenance-aware importer route; drain in-flight provenance-aware requests. The
idempotent stop is:

```sql
select cron.unschedule(jobid)
from cron.job
where jobname = 'import-external-events-eventimolise-provenance';
```

Keep additive schema, guards, records, immutable source snapshots and assets.
Repair/redeploy only a compatible provenance-aware importer after review. Do not
restore the old bundle, recreate `import-external-events-eventimolise`,
reschedule the old city/name/day writer, clear provenance, reset image claims or
drop tables. An expired activation window after cut-over leaves ingestion
stopped and the old writer retired.

## Local rehearsal evidence and limits

```bash
deno test --allow-read supabase/tools/external_event_rollout_preflight_test.ts
bash supabase/tests/run_external_event_rollout_db_test.sh
```

The first suite proves missing backend/client/probe evidence blocks progression,
date-bound success/expiry, a fresh T0, and permanent post-cut-over retirement.
The second uses a test-only localhost HTTP gateway and actual local synthetic
SQL writes: queued/manual invocations already entered must drain, late requests
are rejected after route withdrawal, all legacy inserts precede quiescent T0,
and rollback leaves actual ingestion-created provenance intact. It does not
delete a production route, freeze a production job, prove platform cancellation
behavior, or substitute for production invocation evidence. The local rehearsal
alone left production 10.8 and 9.10 **NOT_EXECUTED**. They were completed
subsequently during the authorized production rollout; see the appended final
production evidence. Future releases still require their own actual production
gate evidence.
