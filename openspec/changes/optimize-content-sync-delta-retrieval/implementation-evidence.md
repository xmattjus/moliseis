# Apply evidence and release checklist

## Baseline and scope

Apply started on clean local and remote `main` at
`58efee0f36c1f1051f49e7c58b0f4d8ef1f79de9`, the approved baseline.
No intervening commits or pre-existing tracked/index/untracked work were found.
Remote `main` was rechecked at the same SHA before finalization.

Verified tooling: Flutter 3.47.5, Dart 3.13.4, ObjectBox 5.3.2 (lockfile),
Supabase CLI 2.119.0, local PostgreSQL 17.6, Deno 2.9.7, Docker 29.7.2.
Only disposable local databases were reset; no linked/production reset,
deployment or client publication occurred.

## M1: database and generated schema

One forward-only migration implements the four exact semantic predicates,
DB-owned strictly increasing UPDATE markers, ordered repair of every legacy
tombstone, four marker defaults/indexes/column comments and the invoker cursor
RPC. Canonical row shape, RLS, created_at defaults, submission/source marker
contracts and provenance enqueue remain unchanged.

Production-writer audit checked the latest promotion/external apply/ingest SQL,
Edge Functions and Flutter boundaries. Supported canonical UPDATE paths do not
change created_at, INSERT paths omit canonical markers, and canonical runtime
removals propagate by soft-delete. Writers use request-scoped RPC transactions.
The 24-hour uncommitted-write assumption remains operational, not DB-enforced
commit ordering. Generic DB/mapper/sync return-to-active fixtures introduce no
supported Event restore operation.

Executed backend runners, all exit 0:

| Runner under `supabase/tests/` | Result |
| --- | --- |
| run_canonical_content_sync_db_test.sh | 10 passed |
| run_canonical_content_sync_migration_db_test.sh | 1 passed |
| run_event_temporal_invariants_db_test.sh | 6 passed |
| run_submission_promotion_db_test.sh | 37 passed |
| run_submission_idempotency_db_test.sh | 11 passed |
| run_external_event_token_e2e_fixture.sh | exit 0 |
| run_external_event_resolution_db_test.sh | 26 passed |
| run_external_event_ingest_db_test.sh | 23 passed |
| run_external_event_moderation_db_test.sh | 20 passed |
| run_external_event_provenance_db_test.sh | 9 passed |
| run_external_event_assets_db_test.sh | 12 passed |
| run_external_event_migration_db_test.sh | 16 passed |
| run_external_event_rollout_db_test.sh | 4 passed |

The upgrade runner creates a separate disposable local Supabase project on port
55432, replays the unchanged historical migrations before the new migration,
seeds all four tables under actual legacy triggers, applies the new migration
once, and verifies exact repair for deleted_at greater/equal/less than the old
marker, unchanged active rows/created_at and replacement triggers. Cleanup was
verified; this is not a backfill simulation under the new schema.

Contract tests inspect function volatility/invoker/search_path/ACL, all four
single-column non-partial indexes and persistent column comments, and exercise
semantic fields/null transitions, no-op/metadata-only writes, immediate writes
and the deterministic future-marker +1us branch. Existing regression assertions
were not weakened.

`deno fmt --check` and `deno check` passed for both new DB test files and
`supabase/functions/_shared/database.types.ts`; runner shell syntax checks passed.
Local `supabase db lint` and `supabase db advisors` exited 0. Existing findings:
unused `proposal` in promote_content_submission; mutable search_path in
add_submission_assets/delete_submission_asset. No finding targets new functions.

### Generated types reproducibility

After successful `supabase db reset --local`, generation used temporary stdout:

```sh
supabase gen types typescript --local --schema public,graphql_public > "$types_tmp"
# Apply the deterministic property-name formatting described below.
deno fmt "$types_tmp"
```

Explicit schemas preserve the checked-in graphql_public schema: this CLI's
implicit schema selection omits it. Its generator also quotes property names
that the existing file leaves unquoted. To prevent unrelated formatting drift,
a temporary TypeScript AST formatter visited PropertySignature and
PropertyAssignment nodes, replacing only StringLiteral names matching
`^[$A-Za-z_][$A-Za-z_0-9]*$` with their identifier spelling, applying source edits
in descending offset order. It imported `npm:typescript@5.9.3` solely for this
temporary tooling step; no repository dependency was added. Then Deno formatted
the output. No generated schema/type was edited by hand.

Generation from the historical schema with the same formatter matched the
checked-in baseline byte-for-byte. Two independent generations from the migrated
schema matched byte-for-byte. The retained diff adds only the four-line
parameterless get_content_sync_cursor entry with string return type.

## M2: genuine ObjectBox compatibility

Before AppSettings changed, a temporary producer with unchanged baseline bindings
created and closed a real store containing non-default settings and four related
canonical rows, with saved Event/Place. It verified Store.isClosed before copying
and compressing data.mdb; the producer was removed. The immutable fixture README
records values, exact producer HEAD and model SHA-256.

The reopen regression verifies old settings/content/relations/identity/saved
state, cursor null, then saves both dates and verifies a second reopen. The
independent pre_all_day regression also passed. Generated model review confirms
AppSettings UID `6:8898619296747710534` and every old UID are preserved, with only
new property `11:6213775870090488596` (dateNano) appended. Bindings have only the
corresponding cursor storage/read/query changes. Unrelated Envied regeneration
was discarded without retaining or exposing environment values.

## M3–M4: retrieval, merge and orchestration

The shared helper uses full rows, id ASC/limit 500, inclusive optional marker
filter, gt continuation and empty-page termination. Tests cover requested-size
and short pages, empty first/final pages, all URI parameters, lower-bound equality,
tombstones/newer markers, page/decode failure and repository-owned decoding.

Real-store merge tests cover freshness, all lifecycle transitions, nullable remote
fields cleared explicitly, saved state, relation semantics, identity and replay.
A review found nullable scalar copyWith parameters retained old values on remote
null; they now use the already-established sentinel pattern, without new model
properties. Independent review confirmed this correction closes the finding.

Controlled Completers verify four preparations start before any completes and
commit waits for all. Cursor acquisition failures short-circuit. A late Media
commit failure occurs after staged writes in all four real boxes; the test proves
all updates/inserts roll back and settings stay unchanged. Another real-store
test fails settings save after content commit, verifies old persisted/in-memory
cursor authority, then safely replays the same rows and saves exactly U. Unit
coverage also verifies UTC normalization, U==C fetches, newer-than-U rows,
Sentry failure status, deterministic three-day scheduling/bootstrap precedence,
forced full/delta selection and cached-upgrade versus fresh-install fatal behavior.

Final combined focused command includes every focused path in tasks.md plus
`test/domain/use_cases/sync_use_case_objectbox_test.dart`: **358 passed**, exit 0.
`flutter analyze`: exit 1 due to **291 pre-existing informational diagnostics**,
identical to the pre-change baseline after normalization by severity, message,
file and rule (ignoring shifted line numbers): **zero new/worsened diagnostics**.
Baseline full Flutter suite: 2148 passed, 6 skipped. The first final full run
found three restoration fixtures with recent lastSyncedAt but no cursor. Their
intended already-synced setup now explicitly supplies a cursor; all three
restoration tests passed without changing production navigation or assertions.
The final full rerun passed **2213 tests, 6 existing skips**, exit 0. Final
analyzer rerun again reports the same 291 infos and zero new/worsened diagnostics.
Final local type generation/formatting compares byte-for-byte with the retained
generated file; Deno format/type checks passed again.

## Release ordering

Local HTTP smoke verifies anon/authenticated cursor access and service_role denial;
the temporary authenticated user was deleted. Missing-RPC client tests explicitly
fail with no fallback or prepare calls.

An additional temporary legacy-client smoke passed one integration test. It
copied exact baseline `58efee0` BaseSyncRepository, Synchronizable, all four
repositories/contracts and City mapper, changing only import relocation. DTOs,
generated DTO codecs and Event/Place/Media mappers have no diff from that baseline.
Actual anon HTTP full-row responses from the migrated local stack were captured
before and after soft-delete on four seeded rows. The old full `.select()` /
prepare / merge paths processed these payloads through the shared HTTP transport
into real ObjectBox: eight prepares/commits, four creations and four deletions,
with identity, relations and Event/Place saved state preserved. The old deletion
branch's retained marker was checked explicitly. SQL fixtures and all temporary
Dart copies/test producers were removed after the passing run. This proves the
installed full-sync behavior, rather than substituting a delta-client test.

Production rollout remains a separate authorized operation:

- [ ] Deploy the forward-only Supabase migration first.
- [ ] Verify deployed marker/comment/index/ACL invariants and regression gates.
- [ ] Smoke anon/authenticated cursor access and installed full-sync compatibility.
- [ ] Only then approve/release the delta-aware Flutter client.

Any backend rollout failure blocks client release. A client rollback can return
to the old full-sync build while retaining the migrated backend; do not revert
marker semantics under installed delta clients. No Event restore RPC/UI/command/
workflow/producer, hard-delete propagation, counters/sequences, CDC/WAL/Realtime,
new dependency/framework/cache/background sync or unrelated marker changes were
introduced. Delta specs have not been synced and the change has not been archived.

## Final planning and scope gates

All 21 tasks are complete. Re-read proposal, design, both delta specs and tasks
against the final implementation; D1–D7 and exclusions remain intact.
`openspec validate optimize-content-sync-delta-retrieval --strict --no-interactive`
exited 0 with `Change 'optimize-content-sync-delta-retrieval' is valid`.
`git diff --check` passed. Final UID comparison removes only the appended cursor
property and restores the previous lastPropertyId; the remainder equals the
original model exactly. No dependency, Supabase configuration, Envied or main-spec
diff is retained. The rollout checklist above deliberately leaves future
production deployment/release unchecked; delivering it and passing local rollout
compatibility gates completes Task 4.6, not a production deployment.
