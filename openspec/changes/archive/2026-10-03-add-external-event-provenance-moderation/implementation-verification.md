# Implementation verification

## M0 baseline — 2026-10-02

Implementation HEAD: `4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade`, exactly the approved plan commit. `git merge-base --is-ancestor` succeeded. OpenSpec CLI: `1.12.0`; Supabase CLI: `2.119.0`.

Initial working tree contained only unrelated modifications, preserved:

- `lib/ui/core/themes/app_color_schemes_theme_extension.dart`
- `pubspec.lock`
- `pubspec.yaml`

Active changes: this change (0/98 initially) and `improve-admin-submission-editor-workflow` (0/25). The latter remains unimplemented; its editor lifecycle/staging work is not absorbed into this change.

Initial strict gate exited 0 with `Change 'add-external-event-provenance-moderation' is valid`.

### Contract review

Reviewed approved proposal/design/tasks/deltas and current importer, Admin Edge validation/store, notification, latest promotion definition, asset RPCs, schema, generated types, DB fixtures, Flutter Admin model/mapper/repository/ViewModels/UI, overlapping editor plan, and canonical temporal/promotion specifications. No material contradiction was found. Current missing provenance/merge/ignore contracts are the expected implementation scope.

Latest promotion is in `20261001175539_add_event_all_day_semantics.sql`, preserving durable replay before pending-only readiness. Actual asset table is `submissions_assets`. Current submissions have no maintaining `modified_at` trigger; Events already do. Notification accepted email uses contributor/name/city/status without promoted IDs. Flutter's start-or-end heuristic does not replace the required backend non-null-start link discriminator. The all-day delta changes ingestion deduplication, preserving existing adapter time interpretation. Event restore remains outside scope.

### Executed baseline

| Command | Result |
| --- | --- |
| `deno test --allow-env --allow-net --allow-read supabase/functions/import-external-events/ supabase/functions/admin-content-submissions/` | Exit 0; 64 passed, 0 failed |
| `deno test --allow-env --allow-net --allow-read supabase/functions/notify-submission-status/ supabase/functions/_shared/` | Exit 0; 26 passed, 0 failed |
| `deno check supabase/functions/import-external-events/index.ts supabase/functions/admin-content-submissions/index.ts supabase/functions/notify-submission-status/index.ts` | Exit 0 |
| `flutter test --no-pub --reporter expanded` | Exit 0; 1702 passed, 2 skipped; all tests passed |
| `flutter analyze --no-pub` | Exit 1; 178 existing diagnostics: 0 errors, 4 warnings, 174 info |
| `supabase db query --linked 'SHOW server_version;'` | Exit 1; `AccessTokenRequiredError`; remote version not verified |
| `bash supabase/tests/run_submission_promotion_db_test.sh` | Exit 1; local Docker socket absent; suite did not run |
| `bash supabase/tests/run_submission_asset_invariants_db_test.sh` | Exit 1; same missing local Docker socket; suite did not run |

Flutter baseline used `/Users/benitomatteobercini/Development/flutter/bin/flutter`; default Homebrew Flutter could not write its sandboxed cache. The writable SDK also needed execution with cache access outside the workspace. No baseline fixes were applied. Logs are in `/tmp/moliseis-m0-{deno-test,notify-test,deno-check,flutter-test,analyze}.log` for this session.

Warnings: `unawaited_return_in_try_block` at `content_submission_view_model.dart:799`; three `experimental_member_use` diagnostics at `content_submission_description_form_field.dart:150`. Remaining diagnostics are informational and remain unchanged.

### Initial blocked attempts

At the initial pause, M0.2 was blocked until authenticated remote read access permits `SHOW server_version;` (repository configuration is major version 17; cached/configured values are not a substitute).

At the initial pause, M0.3 was incomplete until local promotion/assets DB baselines can run. Docker socket is missing; installed `/Applications/Docker.app` cannot launch (`kLSNoExecutableErr`, executable missing). No remote production database is used for tests.

At the initial pause, no production source edits, migrations, test edits, commits, deployment, audit/backfill or cut-over had occurred. M1 waited for complete M0, as explicitly required by the user.

## M0 resumed — 2026-10-02

HEAD unchanged. With execution outside the sandbox, linked remote `SHOW server_version;` exited 0 and returned `17.6`, satisfying M0.2 and configured major 17. Local Docker is now available. Promotion baseline: exit 0, 37 passed/0 failed. Asset baseline: exit 0, 4 passed/0 failed. Both report the expected local warning `notify-submission-status Vault configuration is missing`; no real email was sent. Previous access failures were environmental, resolved by access to CLI credentials/Docker. Together with the previously recorded Deno/Flutter/analyzer results, M0.3 is complete and all five M0 tasks pass. M1 is now authorized to begin; no production deployment is authorized.

## M1 — additive schema and guards

Tasks 2.1–2.9 completed sequentially with focused tests at each gate. Added `20261002163130_add_external_event_provenance.sql`, real DB suite/runner, regenerated `_shared/database.types.ts` (only 100 intended inserted lines), and removed application-authored modified_at from Admin content Save (existing call signature retained; status writes unchanged).

Final new DB suite: 9 passed/0 failed, independently rerun by root and reviewer. Existing promotion: 37 passed; assets: 4 passed; Admin store: 15 passed. Focused Deno format/type checks pass. Local security advisors exit 0 with only three pre-existing mutable-search-path warnings on asset/promotion functions. Strict OpenSpec validation and diff check pass. Independent adversarial review found no material issue.

Tests cover identity/null occurrence uniqueness, source/submission structural checks and RESTRICT FKs, partial pending uniqueness, immutable populated provenance, every merge-content column invalidating equality tokens, repeated same-transaction microsecond advance, no-op Save, status/link guards, transaction-local context reset, actual anon/authenticated ACL denial and service-role access. Existing null-provenance history remains compatible.

Driver finding: postgres.js timestamp-typed test parameters can lose microseconds via Date serialization. Token tests bind opaque strings as text before PostgreSQL timestamp casts. Production RPC tokens must likewise remain strings as already specified.

Local DDL was applied incrementally via Docker psql without resets or remote writes; the migration is not yet registered in local history. Complete fresh forward-migration replay remains a final verification gate. No commit, production deployment, backfill or cut-over occurred. Implementation HEAD remains `4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade`. Next: M2.

## M2 — blocked by normalized rich-text representation

M2 remains unchecked/WIP. Added shared canonicalizer/tests, actual jsonb/PostgREST hash round-trip test/runner, and adapter/handler preparation for strong identity. No ingest SQL/RPC was implemented or applied; the empty generated ingestion migration was removed. Preliminary canonicalizer/importer tests passed, but a newly reproduced mandatory compatibility regression is red.

Existing Admin accepts description `e\u0301` with Delta operations `{insert:"e",attributes:{bold:true}}` and `{insert:"\u0301\n"}`. Normalizing description to NFC `é` while preserving the two operations makes an exact loaded-field no-op Admin update fail `description does not match description_delta plain text`. Current editor ViewModel loads both stored fields as-is; the description widget does not call onChanged on initialization. A claim that no-op Save automatically re-derives literal description was disproved.

Permanent regression: `_shared/external_event_normalization_test.ts`, test `canonical source Delta survives exact loaded Admin no-op Save`. It first proves the raw input accepted, then asserts canonical loaded input accepted. `deno test supabase/functions/_shared/external_event_normalization_test.ts` exits 1: 10 passed, 1 failed (`error: Test failed`). No validator relaxation or representation decision was selected.

Execution stopped before M2 ingest under the user's mandatory material-contradiction gate. Proposed minimum OpenSpec clarification for review: when Delta exists, description is the exact plain projection of canonical operations; NFC applies per insert, not across formatting boundaries. Description without Delta retains NFC. This exception preserves operation order/attributes and existing strict Admin validation. It requires explicit approval before changing the approved normalization contract.

M0 and M1 remain complete (14/98 tasks). M2 WIP is not ready to deploy. No commit or production deployment/backfill/cut-over occurred.

## M2 resumed — approved Quill clarification

The user approved the local normalization-contract correction: per-insert NFC must preserve operation boundaries and attributes; description with Delta is exactly the canonical inserts plain projection minus terminal newline, while global NFC comparison validates input semantic equivalence. Scalar description without Delta retains NFC. Updated design, external provenance delta spec and tasks 3.1/3.2 with all six prescribed regressions. Before resuming production edits, `openspec validate add-external-event-provenance-moderation --strict --no-interactive` exited 0 with `Change 'add-external-event-provenance-moderation' is valid`; `git diff --check` exited 0 with no output. No architecture review is required by the approval. M2 resumes from the previously failing canonicalizer regression; remaining tasks are not marked complete until their tests pass.

Tasks 3.1–3.4 verified: 12 canonicalizer and 21 importer tests pass (33 total), independently rerun by root; canonicalizer/importer Deno type checks pass. The previously red exact loaded Admin no-op Save now passes, as do per-insert composition, formatting-boundary preservation, attribute-value preservation, equivalence/hash, idempotence and mismatch regressions. Actual local JSONB/PostgREST round-trip passes (1 test), independently rerun by root. Bounded review found no directly conflicting normalization statements in the six plan artifacts. Next gate: transactional ingest/enqueue/initial identity (3.5 onward); no M3 execution yet.

Tasks 3.5–3.6 pass: service-role-only per-record ingest uses INSERT ON CONFLICT then record FOR UPDATE, material-only current updates and single private enqueue projection, with existing-workflow identity inheritance. Projection exposed existing PostgreSQL `extra_float_digits=0` (configuration-file setting): both SQL and actual PostgREST emit 15 significant digits from float8. Since the approved plan leaves exact coordinate representation to task 3.1, v1 now freezes 15 significant digits in TypeScript only, validating geographic bounds before rounding; SQL and DB configuration remain unchanged. Task 3.1 was reopened during the failing projection and closed only after the correction passed. Root independently reran 34 canonicalizer/importer tests and 4 actual local DB/PostgREST tests, all passing, including cross-operation Quill literal description, coordinate strings and microseconds before any Admin Save. Tasks 3.7 onward remain pending.

Task 3.7 passes in the 7-test local DB suite: authoritative trimmed Auth identity, invalid/missing contributor data rolls back source creation, configuration changes seed only new workflows, historical identity inheritance, actual anon/authenticated denial and service-role success, and no API-role execution grants on private helpers. Next: 3.8 importer RPC response integration, then remaining concurrency/readiness/projection gates.

Task 3.8 passes: importer issues only the typed per-record ingest RPC with configured UUID; removed legacy Edge Auth identity fetch and direct automatic submission INSERT. Regenerated RPC types from actual local schema. Agent reports 11 importer transport tests and 7 real DB tests passing, including actual PostgREST RPC response/null occurrence and fail-closed malformed outcomes. Root importer type check and diff check pass. Existing source-media helper integration remains WIP until M7 irreversible claim; no production rollout is authorized. Next: 3.9 concurrent first ingest and remaining M2 gates.

Task 3.9 passes with an 8-test DB suite: deterministic three-session overlap observes a follower waiting on the first uncommitted strong identity, then proves one record, one pending and only one pending_created winner. M2 review identified fixed-prefix starvation from slicing observations before ingest; this is an implementation regression, not an OpenSpec contradiction. The bounded fix preserves the released new-pending creation limit, counts only pending_created winners, and adds repeated-run/listing/later-update regressions without semantic prefiltering. Task 3.11 remains open until verified.

Task 3.10 passes: 37 focused Deno and 9 DB tests. Edge invalid/null start, invalid Gregorian dates, chronology and all-day ranges never reach the RPC; malformed privileged ingest missing/null start or inverted microsecond chronology creates no record. Independent M2 review found no additional material issue beyond fixed-prefix starvation. Remaining 3.11 traversal/report fix and 3.12 complete fixture projection gate are pending.

Task 3.11 passes: 13 Edge orchestration/transport and 11 actual DB tests. Fixed creation-budget starvation; reviewer independently reran 13 tests and confirmed the P1 resolved. Repeated observations/listing appearances consume no creation budget, later updates are reached, and limit_reached reflects unvisited observations. Source-only dry-run explicitly reports would_insert_upper_bound rather than duplicating authoritative enqueue decisions or claiming exact proposals; it is separate from M8 audited production-contract dry-run. Tests prove unchanged observations reevaluate enqueue without updating current token, metadata-only handled state produces no proposal, identical metadata is immaterial, and one failed record transaction does not roll back another committed record. Final M2 gate 3.12 is pending.

## M2 final gate and M3 execution-order contradiction

All twelve M2 tasks pass. Root final independent reruns: Deno shared/importer/Admin 103 passed; ingest DB 23 passed; schema DB 9 passed; promotion 37 passed; assets 4 passed. Deno format checks (9 files) and affected type checks pass. Agent focused lint passes with only the existing unversioned Edge runtime import rule excluded; local security advisors report only the same three pre-existing warnings. Strict OpenSpec validation and diff check pass. Implementation HEAD remains `4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade`; no commit, deployment or production data operation. M0–M2: 26/98 tasks complete.

Before M3 source edits, the strict milestone/task order exposes forward dependencies: task 4.6 requires the complete submission→record→Event lock/promotion overlap proofs; task 4.8 requires identity inheritance after link/apply/promotion; task 4.12 requires their stale acknowledgement/same-target retry handler proofs. Those runtime operations are created by M4 tasks 5.1–5.9. The current three-argument promote_content_submission (20261001175539) locks only the submission and has no external record/watermark/acknowledgement handling or resolution GUC; the M1 OLD-imported guard rejects its resolution writes. No link/apply RPC exists. Mocks or a denial-only legacy promotion test cannot prove the prescribed successful operations.

Execution stops before M3 to respect the user's absolute sequential gates. Minimum proposed planning correction retains all requirements/design: M3 proves reject/un-ignore/ingest branches and their locks/identity/acknowledgement; M4 explicitly owns the corresponding successful promotion/link/apply concurrency, identity and acknowledgement/idempotency proofs. The OpenSpec task-order correction has not been applied without approval. The intermediate importer remains non-deployable until M7 asset claim integration. Full Flutter final gate/fresh migration replay/M3–M9 remain incomplete.

## M3 resumed — approved task-order correction

The user approved the minimum M3/M4 test-gate reorder, including explicit M3 lock-prefix wording and representative M4 concurrency overlaps. Applied tasks 4.6/4.8/4.12 and retained all moved proofs explicitly in 5.3/5.5/5.6/5.8/5.9. Architecture, requirements and rollout are unchanged; 98 tasks remain. Before resuming source edits, strict validation exited 0 with `Change 'add-external-event-provenance-moderation' is valid`; `git diff --check` exited 0 without output. M3 resumes sequentially from 4.1; no further architectural approval is required for this authorized reorder.

M3 task 4.1 passes in the new 2-test real DB suite: existing pending, ignored, current/proposed equality, new proposal rollback, linked soft-deleted Event suppression without watermark advancement. The M2 private helper already enforces the required record lock; no additional production change needed for this task. An initial incomplete Event test fixture was corrected against actual required coordinates before the passing run. Next: 4.2 transactional external reject.

Task 4.2 passes (4 moderation DB tests): service-role-only authoritative reject in forward migration 20261002175147_moderate_external_event_sources.sql locks submission then record, advances reviewed snapshot watermark, sets ignore before enqueue, inherits identity and restores transaction-local resolution context. X pending/current Y produces Y atomically; non-pending retry conflicts; invalid inherited identity rolls back status/watermark; ignore suppresses replacement. Existing local notification Vault warning is expected until structural suppression M7. Next: guarded current-source acknowledgement.

Task 4.3 passes (5 moderation DB tests): actual stale state and original expected_source_hash validated under both locks before writes. Matching shown Y acknowledges current Y without redundant proposal; non-stale, missing and outdated hashes return source_changed without status/ignore/watermark changes. Next: authoritative un-ignore and historical identity ordering.

Tasks 4.4–4.5 pass (9 moderation DB tests): record-only un-ignore immediately reevaluates proposals without requiring a pending, exact handled_at DESC NULLS LAST/id DESC usable-identity ordering, rollback on missing historical identity, current/equal watermark no-op, and duplicate pending SQL23505 fallback preserving one pending. Next: deterministic M3-prefix concurrency and legacy imported-promotion denial regression.

Tasks 4.6–4.8 pass. Concurrency coverage repaired to include explicit ingest→un-ignore: 14 DB tests, observed lock waits and NOWAIT probes prove record-only operations and submission→record reject prefix; each overlap preserves one pending and avoids deadlock. Root independently reran the prior 13-case suite before this added pair. Legacy imported promotion reaches readiness then fails the resolution guard with Event insert rollback. Admin routing/store/handler/validator focused suite: 47 pass; immutable provenance dispatches external reject and retains human pending-only rejection/closed actor envelopes. Identity strengthening: 16 DB plus 12 validator tests pass, proving reviewed-submission identity wins for Reject follow-up and exact usable historical ordering for un-ignore. M4 Event-resolution coverage remains explicitly assigned to the approved later tasks. Next: 4.9 linked soft-deleted ingestion suppression.

Tasks 4.9–4.10 pass: 18 moderation DB and 50 focused Admin tests. Actual ingest updates current/hash/metadata for a linked soft-deleted Event without pending insertion or proposed-watermark advance; hash equality alone does not suppress a differing version. Strict optional ignore_source travels with JWT-derived actor to external reject; imported success returns follow-up pending ID. Human original rejection remains compatible and a true inapplicable source-ignore option is rejected without status write. Caller actor/importer identity and accepted-status envelopes remain rejected. Next: explicit ignored-source Admin operations and complete reject stale detail/acknowledgement.

Task 4.11 passes: 53 focused Admin and 19 moderation DB tests. Authenticated explicit listIgnoredSources/unIgnoreSource use closed envelopes without actor/importer fields, list ignored records independently of pending existence and call authoritative set_source_ignored(false). Success/not-found/failure responses verified, plus actual anon/authenticated RPC denial and service-role access. Review identified a bounded Reject routing race with authorized legacy NULL→full provenance backfill: the human conditional write must retain NULL provenance and classify a newly imported pending as the existing external_requires_resolution conflict, rather than leak a guard exception. This implementation bug is being fixed before final M3 gates; no design change. Next: complete 4.12 stale detail and original-hash Reject acknowledgement.

## M3 final verification

All twelve M3 tasks pass, following the approved minimal task reorder. Root independently ran 122 shared/importer/Admin/notification Deno tests and 20 real moderation DB tests, all passing, including Admin handler→real store→PostgREST→RPC acknowledgement and four observed-lock overlaps. Reviewer independently reran 58 focused Admin tests and found no remaining material issue. Worker reran M1 DB9, M2 DB23, promotion37 and assets4, all passing; affected format/type checks pass. Lint has no new finding: eleven verified pre-existing findings in Admin index/index_test remain, while the five other scoped files lint cleanly. Security advisor retains only three existing warnings. Strict validation and diff check pass.

Fixed the authorized NULL→full backfill/Reject routing race using a NULL-provenance conditional human write and fresh classification; a newly imported pending now returns stable external_requires_resolution/HTTP409 with reload copy rather than a guard exception/500. Detail exposes immutable external snapshot/hash/version, external record/target IDs and authoritative current moderation_hash/current_source_normalized; original observed source hashes remain unchanged across rereads. Source options remain Admin-only and body actor/technical identity overrides are rejected.

Main files: Admin handler/store/validator and their tests; generated RPC types; new 20261002175147_moderate_external_event_sources.sql and moderation DB suite/runner. Local migrations were applied directly without migration-history registration; complete fresh forward replay remains a later verification gate. Implementation HEAD remains 4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade, no commit/deploy/production data operation. M0–M3 complete: 38/98 tasks. Next: M4, retaining TypeScript merge calculation in M5.

M4 task 5.1 verified: new forward migration `20261002181549_resolve_external_event_submissions.sql` initially copies exactly the latest promotion definition and grants from `20261001175539_add_event_all_day_semantics.sql` (root compared text). Applied only locally; root independently reran all 37 promotion readiness/replay/media/all-day regressions, PASS (`/tmp/moliseis-m4-promotion-baseline.log`). HEAD unchanged, no commit/deployment. Tasks 5.2 onward remain pending.

Task 5.2 verified: root inspected durable promotion retry preceding pending checks, imported submission lock followed by external-record FOR UPDATE, and event-target source_already_linked before publication/readiness mutations. Implementer ran the real resolution DB regression (1 PASS, no Event/status/watermark mutation) and 45 focused Admin store/handler tests. Compatible Edge 409 PROMOTION_SOURCE_ALREADY_LINKED mapping was implemented/tested before the local function could emit the outcome, as required by task 5.4; task 5.4 will be closed after the 5.3 gate in listed order. No production deployment.

Tasks 5.3–5.4 pass: imported promotion writes reviewed Event/source linkage/snapshot watermark and enqueues Y with reviewed submission identity atomically; explicit matching current acknowledgement accounts for Y without replacing reviewed Event content or adding Y pending. Missing/non-stale/old hash failures leave Event/status/watermark unchanged; durable already_promoted retry retains precedence. Root independently ran 4 resolution DB and 45 Admin store/handler tests, PASS. Implementer ran all 37 legacy promotion and 20 M3 moderation tests, PASS. Actual three-argument PostgREST request remains unambiguous after DROP of old signature and creation of five arguments with two defaults. Source-already-linked mapping was available before local emitting function application.

One existing optional security assertion required adaptation: SECURITY INVOKER cannot call the intentionally closed private enqueue helper. Neither canonical/delta spec prescribes invoker; design220 requires private helpers closed and resolutions service-role-only. The new promotion uses the same service-role-only SECURITY DEFINER/empty search_path boundary as ingest/reject, without broadening caller grants. Test now checks definer, empty search_path, exactly one 5-argument signature/two defaults; actual anon/authenticated 42501 and service-role probes remain unchanged. M3's legacy unsupported promotion fixture evolves to unsupported direct-resolution guard fixture, since promotion is now supported. Root inspected both changes; independent bounded promotion review is running. All deployment remains unauthorized; HEAD unchanged. Next task5.5.

Independent bounded review of M4 tasks5.1–5.4 found no material issue: fully qualified relations/helpers and empty search_path, unchanged actual API-role denial, unambiguous old envelope, replay precedence, CS→record ordering, reviewed-content publication, atomic identity/watermark/enqueue and unchanged media/readiness verified. Pending Save/ack handler tasks were not treated as completed by this subset review.

Task5.5 verified: transactional Event link requires locked non-null start for human/imported create/update; accepted same-target retry wins before pending/discriminator/ack/target checks; different resolved target conflicts, implicit source relink conflicts. Target Event active lock follows CS→record; content/media unchanged. Human Place-like/end-only fail without mutation, valid human Event accepts with target_event_id and no promoted ID. Imported non-stale/missing/drift acknowledgement rejects without writes; matching current acknowledges Y without extra pending. Edge strict envelope/JWT actor/original expected hash/stable422+409 mapping tested. Root inspected SQL and independently reran resolution7PASS and Admin63PASS (`/tmp/moliseis-m4-link-{db,admin}.log`). End-only malformed legacy fixture drops a temporal constraint only inside rolled-back test transaction. Next5.6 apply SQL precondition gates; no M5 merge implementation.

Task5.6 verified: service-role apply primitive enforces CS→record→Event locks, imported/pending/update/base/compatible-version/active-target preconditions, exact timestamp equality with supplied original tokens, source acknowledgement and rollback. Same-target durable replay precedes pending/groups/tokens/ack checks. Root inspected SQL (no normalization/merge calculations) and independently ran resolution9PASS and Admin64PASS. Store has typed closed server groups and unchanged token plumbing; pending HTTP orchestration remains M5. Complete atomic SQL copies were included with preconditions to avoid an intermediate accepting RPC that ignores groups; task5.7 will separately demonstrate group/city/media invariants.

Task5.7 verified: all five closed groups copy locked moderated fields, description/Delta, schedule/all_day/microseconds and exact active city/coordinates move together; unrequested groups and both media collections remain unchanged. Existing Event trigger advances sync token. Missing city rejects before any write; enqueue identity failure after group writes rolls back Event/resolution/watermark. Root reran resolution13PASS and Admin65PASS, including exported closed outcome mappings; pending Apply HTTP orchestration is not claimed. Logs `/tmp/moliseis-m4-atomic-groups.log`, `/tmp/moliseis-m4-group-mappings.log`. Next5.8 full identity/invariant/concurrency gate.

Task5.8 verified: root independently reran all20 resolutionDB tests PASS (`/tmp/moliseis-m4-concurrency.log`) and inspected real backend PID Lock waits/NOWAIT ownership probes/10-second SQL bounds, not timing-only simulated races. Link/Apply hold CS+record while waiting Event and overlapping ingest subsequently converges to one pending without deadlock; promotion/retry/ingest creates one Event and one follow-up pending. Identity inheritance, deleted/missing targets, invalid/duplicate groups, 1µs preview mismatch, semantic content token invalidation and real role denial included. Independent bounded review of5.5–5.7 found no material issue; M4 pending HTTP orchestration not certified.

A new task-order dependency is confirmed at5.9/5.12: current production parser/handler has Link but no Apply dispatch; pending Apply server group recomputation first exists in M5 tasks6.2/6.6. Accepted-only Apply endpoint would require a false pending error/temporary stub, caller groups, or early M5 implementation. None introduced. Review-only minimal task patch prepared at `/tmp/moliseis-m4-m5-order.patch` (approved tasks untouched apart from completion checkboxes): retain all M4 SQL/retry/readiness and Link/promotion plumbing, move only Apply HTTP retry/ack handler and Edge-before-merge validation proofs to6.6. User approval requested asynchronously; dependent5.9 edits remain paused. Progress46/98, HEAD unchanged, no commit/deployment.

Before pausing on the confirmed task-order dependency, root additionally reran M3 moderation20PASS and promotion37PASS, Admin entrypoint Deno typecheckPASS and formatter10filesPASS. Strict OpenSpec output remains `Change 'add-external-event-provenance-moderation' is valid` (exit0), diffcheck no output (exit0). No dependent5.9/5.12 source edits made.

User approved M4→M5 task-only reorder: applied4.12/5.9/5.12/6.6, retaining5.8 checked and clarifying5.12 RPC/store outcome/mapping vs actual Apply-handler HTTP proofs in6.6. No requirement/design/coverage changed. Strict validation and diffcheck are mandatory before affected execution resumes.

Approved reorder validation: initial mechanical edit introduced duplicate6.6 task numbering; strict validation caught it before production edits. Corrected task IDs and the approved5.12 wording, retained checked5.8; strict command then exited0 with `Change 'add-external-event-provenance-moderation' is valid`, diffcheck exited0/nooutput. Resumed5.9 only after both PASS.

Tasks5.9–5.10 verified after root found and resolved a missing integration proof: initial unit handler + outer-transaction SQL fixture did not alone demonstrate a committed lost-response retry. Added actual Link createHandler→real store→PostgREST RPC first committed resolution and same-handler retry; Apply first/retry through actual PostgREST commit. Complete Event/record/all-source-submissions snapshots stay identical after retry with obsolete hash/token/groups; different target conflicts. Root independently ran23DBPASS and68AdminPASS (`/tmp/moliseis-m4-retry-integration.log`, `/tmp/moliseis-m4-ack-handler.log`). Promotion parser/store/handler preserve displayed hash/JWT actor and source_changed409; legacy envelope/retry precedence maintained. Imported Event→Place still fails existing temporal readiness, first-link/no-base remains link-only, human discriminator/group-rejection tests retained. Apply HTTP proofs remain6.6 per approved reorder. Next5.11.

Task5.11 verified: null-start Admin Save uses atomic pending/id/external_event_record_id IS NULL UPDATE, then authoritative provenance reread yields start_date_required422, covering concurrent verified provenance without preread TOCTOU. Human Place editing remains allowed. Root inspected predicate/classification/HTTP mapping and independently ran71AdminPASS; actual real-handler/store/PostgREST imported null-start request returns422 and entire persisted row remains identical. First broader root resolution run passed preceding23tests but newly added5.12 snapshot fixture failed on wrong assets-column name (submission_id). Implementer corrected to content_submission_id;5.12 stays unchecked pending rerun. No production schema/contract error inferred from fixture typo.

M4 final gate PASS,50/98tasks: root resolution24/24 and full shared/importer/Admin/notification Deno135/135, strict `Change 'add-external-event-provenance-moderation' is valid` exit0, diffcheck exit0/nooutput. Null/inverted moderated schedules with name-only/schedule/emptygroups fail without Event/media/assets/CS/source/watermark/enqueue changes. Independently reviewed5.9–5.12 (and earlier5.1–5.8), no material finding/missing prescribed proof after approved reorder; reviewer independently71AdminPASS. Scoped formatting10/typecheck/lint5PASS, pre-existing lint/advisor findings unchanged. HEAD4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade, no commit/deploy. Main productionfiles new resolutionmigration/Adminstore+validator+handler/generatedtypes; supportingDBandDeno tests. Actual production Apply HTTP retry/readiness-beforemerge remains6.6, no partial endpoint introduced. M5 may now start sequentially6.1→6.8.

Task6.1 verified: persisted submission and Event projections share one internal TypeScript field canonicalizer, exact ten-field/microsecond/coordinate/NFC/Delta rules. Current Event.city_id nullable is faithfully represented as null in comparison projection; source/submission city remains strict nonempty, with no source-city substitution or source-hash contract change. Root inspected sole implementation and independently ran30canonicalizer+Adminvalidator testsPASS (`/tmp/moliseis-m5-projections.log`). No SQL canonicalization introduced. Next6.2.

Task6.2 verified: one shared closed-group field map/type and pure TypeScript providerChanged/moderatorChanged/apply/overwrite formula with complete description/schedule/location projections; no SQL merge semantics. Root inspected exact formulas and independently ran18merge+canonicalizer testsPASS (`/tmp/moliseis-m5-merge.log`), covering unchanged placeholders/editorial preservation, provider and moderator-only overwrites, current==moderated/base and cancel-to-base apply. Next6.3 actual Admin no-op Save regression.

Task6.3 independently verified: actual committed external snapshot→ingest/enqueue→production Admin getById→no-op Save→persisted sharedcanonicalization equals snapshot and all5moderator_changed flagsfalse. Fixture includes NFC cross-Quillformattingboundary literal description, microseconds and coordinateprecision. Separate from M2 SQL-before-Admin projection regression. Root resolutionDB25PASS (`/tmp/moliseis-m5-noop-save.log`). Next6.4 advisory candidates/manual lookup.

Task6.4 verified: authenticated strict eventCandidates operation rereads authoritative pending; automatic exact active city/same Rome-day candidates, existing normalized-text name evidence, separate nonselectable similar-pending warnings, and manual name/ID fallback across city/day. Existing matching functions moved unchanged to shared helper and importer reexports preserved. ActiveEvent candidates cap50, softdeleted excluded; unknown sourcecity leaves manual lookup available. Root inspectedqueries/escape/validator and independentlyresolutionDB26PASS (`/tmp/moliseis-m5-candidates.log`), actual handler/store/PostgREST tests refresh/nullablecity/manual/warnings. Implementer26focusedpure/importer/validatorPASS. No persistence/canonical-blocking/pg_trgm. Next6.5.

Task6.5 independently verified: closed authenticated mergePreview returns complete atomicgroup/current values/flags, current-source stale/hash/snapshot, and unchanged raw DB modified_at strings as submission/event tokens. Preview refreshes persisted authoritative inputs and validates eligibility/version/readiness before canonical projections. Root inspected helper and ran33handler+mergePASS, resolutionDB26PASS including actual PostgREST token byte equality (`/tmp/moliseis-m5-preview{,-db}.log`). Sourcecity semantics unchanged; missing canonical city remains null. Next6.6 actual ApplyHTTPorchestration/lostresponse/ack/readiness gates.

M5 final gate PASS,58/98tasks: root149/149 shared/importer/Admin/notification Deno,26/26actualDB, Admin/importer entrypoint typechecks, diffcheck, strict validationPASS. First final Deno run observed148PASS/1FAIL on newly-added normalization-version2 test while profile guard was being completed; production stabilized with explicit current v1 requirement before pending canonicalization, rerun149PASS. Source/proposed/submission agreeing on an unsupported profile can no longer pass through v1 interpretation. Accepted durable retries still precede this pending-only check.

Tasks6.6–6.8 actual committed Apply HTTP initial success/lostresponse retries, matching/missing/non-stale/drift acknowledgement and stale original preview token failures independently exercised through handler/store/PostgREST; owned snapshots unchanged on errors/replay, different target conflicts. Pending temporal422-before-canonical/merge has poisoned-Delta handler calltrace onlygetById plus separate real locked SQL no-mutation snapshots (inverted constraint alteration only rolled-back fixture, never global committedDDL). Original tokens/hash/JWT actor forwarded unchanged; caller groups/actors rejected. Reviewer independently98pure/AdminPASS and inspected actual committed DB assertions, no materialfinding. Scopedfmt14/lint9PASS; existing baseline diagnostics unaffected. NoM5schema/migration changes, packages, Flutter/M7/M8source edits, commit or deployment. Main new productionhelpers sharedmerge/candidates; sole sharedcanonicalizer projectedEvent nullablecity; Admin eventCandidates/mergePreview/apply. NextM6 sequential7.1–7.12.

## M6 — Admin transport and editor integration

Tasks7.1–7.2 completed: nullable external create/update provenance, authoritative source hashes/snapshot, candidate/atomic merge group models and opaque String preview tokens added to handwritten Admin contracts/mapper/repository. Admin detail exposes record-derived external_mode/external_event_id, avoiding confusion with acceptance target_event_id. Focused mapper/model29PASS and repository/editor/dashboardVM95PASS (`/tmp/moliseis-m6-contract-flutter.log`); root independently reran AdminDeno79PASS (`/tmp/moliseis-m6-wire-root.log`). Repository test asserts byte-identical Edge JSON→model→Apply request tokens. No Dart canonicalizer or generated input changed.

Local writable FlutterSDK3.47.4 conflicts with unrelated existing pubspec constraint3.47.5 during dependency solving; focused --no-pub tests compiled/passed without dependency edits. Root verified installed `/opt/homebrew/Caskroom/flutter/3.47.5/flutter/bin/flutter --version` exit0 (Flutter3.47.5/Dart3.13.4); remaining/final gates use compatible SDK. Preserve all three unrelated initial files. Task7.3 in progress; no milestone-complete claim before full M6 tests/review. HEAD unchanged; no commit/deployment.

Task7.3 completed: create imported Publish/Link, update Link/Preview/Apply, human Event optional Link preserved. EditorVM/widget116PASS with compatible Flutter3.47.5 --no-pub (`/tmp/moliseis-m6-flows.log`), including human Link acceptance without promotedID and original Apply tokens. Existing Publish widget scroll fixture now waits after ensureVisible for shifted controls; no navigation/lifecycle refactor. Independent incremental review7.1–7.3 underway. Next7.4 candidates/warnings/manual lookup.

Task7.4 completed: canonical candidate selection, separate advisory similarPending warnings and manual name/ID lookup; warnings never block resolution. Repository/VM/widget139PASS under Flutter3.47.5 (`/tmp/moliseis-m6-candidates.log`), exact manual lookup envelope and Link success with warning covered. Next7.5 complete-group KeepCurrent via ordinary persistence/invalidate/new preview; existing Save navigation behavior retained.

Independent incremental M6 review:167focusedFlutterPASS; found7.1 gaps despite initial focusedPASS. List emitted null external_mode/external_event_id because only detail fetched record state; independently decoded identical imported AdminSubmission values became unequal due provenance identity-only equality. Root temporarily reopened7.1 and assigned minimal batch-list projection/deep provenance value equality with regression tests before7.5 execution. These are implementation/test gaps, not OpenSpec contradictions.7.2–7.4 remain verified.

Task7.1 review fixes implemented/tested: list batch-loads referenced source records in one additional query, human-only lists issue none; wire now includes real create/update linkage/current snapshot/hash. Provenance has deep value equality/coherent hash, independently decoded identical imported AdminSubmission equals and changed hash/mode/EventId/target differs. Root inspected both fixes and independently81DenoPASS (`/tmp/moliseis-m6-wire-fixes-root.log`); worker model/mapper/repository51FlutterPASS (`/tmp/moliseis-m6-model-fixes.log`).7.1 checked again; reviewer verifying closure.7.5 implementation initially self-blocked preview via keeper-running guard; implementer resolving before advancement.

Reviewer independently confirmed both7.1 findings closed, no new finding; no extra test rerun claimed. Task7.5 completed: KeepCurrent Command copies full canonical name/category/description/schedule/location group, invokes ordinary Save persistence, invalidates and reloads preview while existing Save button navigation remains unchanged. Nullable Event city stays null and fails ordinary required-city validation without substitution or persistence. Preview generation guard prevents in-flight stale results restoring old tokens after edit/Save. VM/widget124PASS (`/tmp/moliseis-m6-keep.log`); root inspected group-copy/temporal projection. Independent7.4–7.5 review next;7.6 stable actionable feedback in progress.

Independent7.5 review found UI hydration gap: shared city/name TextFormFields use initialValue, retaining visible old text after KeepCurrent persistence while VM holds copied current values. Existing test asserted repository/route but not displayed values. Reopened7.5 pending scoped programmatic city/name hydration and visible-value/subsequent-edit regression; no broad public editor refactor. This is implementation/test gap, not architecture contradiction.

Task7.5 hydration finding closed by independent reviewer: optional null-default shared field hydrationRevision keys actual city/name/description controls; Admin increments only load/programmatic copy. Public default/ordinary typing/asset rebuilds unchanged. Widget assertions now cover displayed canonical name/city, null→empty/no persistence, subsequent editing/Save, and route retention. EditorVM/widget/publicfields152PASS (`/tmp/moliseis-m6-hydration.log`).

Task7.6 completed: stable API status/code/message preserved and actionable boundary feedback covers all required new/existing resolution/temporal/conflict codes;175FlutterPASS (`/tmp/moliseis-m6-errors.log`), current hydration run includes20 typed-error VM/widget cases.7.7 compatibility regression/7.8 editor overlap next;7.9 typed Reject options/pending result keeps single existing rejection boundary.

Tasks7.7–7.8 completed: malformed promotion-success body with409PROMOTION_SOURCE_ALREADY_LINKED remains typed API error and never success-parses. Repository/dashboard/Adminrouting59PASS (`/tmp/moliseis-m6-compat-overlap.log`). Overlapping improve-admin-submission-editor-workflow remains0/25; existing createID/photo staging/normal Save pop/dashboard return unchanged. Only authorized KeepCurrent Command stays/recomputes locally. No unrelated Save/navigation work absorbed. Next7.9 resolution options and ignored-source transport.

Task7.9 completed: single existing Reject repository path returns typed rejected resolution/nullable pending ID while human editor Command remains void. Optional named ignore/ack/expected hash across Reject/Promote/Link/Apply, raw tokens/hash unchanged, no body actor. Minimal ignored list/un-ignore exact transport parses outcomes/pending IDs and verifies authenticated request/403. Repository/editorVM/widget180PASS (`/tmp/moliseis-m6-source-transport.log`); shared fakes preserve older void result/completer fixtures through mapping. Next7.10 stale state/current hash/ack Commands and refresh/reset paths.

Independent7.6–7.9 review found cross-operation feedback bug in shared Link/Apply listener: persisted prior Link.error took precedence over current Apply result, potentially masking current boundary/source-changed errors or surfacing old error at Apply start. Reopened7.6 for per-command terminal listener selection and failed-Link→failed-Apply regression;7.10 edits preserved but fix gate precedes advancement. No OpenSpec contradiction/new architectural decision.

Task7.6 listener fix completed: separate Link/Apply listeners ignore running/idle and handle only their own terminal result. FailedLinkSOURCE_CHANGED→Apply start(no old snackbar)→ApplyEVENT_CHANGED regression passes.189FlutterPASS (`/tmp/moliseis-m6-feedback-fix.log`); root inspected listener/disposal paths.

Task7.10 completed: displayed stale hash captured explicitly, threaded unchanged through all four resolution Commands; SOURCE_CHANGED causes refetch and acknowledgement reset, renewed selection captures new observed hash. Non-stale cannot select; preview observes newer source updates displayed snapshot/hash and clears earlier selection; successful Reject reloads resolved/follow-up pending. Mapper/repository/editorVM/widget209PASS (`/tmp/moliseis-m6-ack-vm.log`). Next7.11 ignore/stale UI and7.12 ignored-source dashboard.

Task7.11 completed: imported Reject exposes ignore with exact revision-level discard/future suppression-until-reactivation explanation; stale-only acknowledgement/current source snapshot; imported Event-mode removal disabled in UI/VM while backend remains authoritative. SourceChanged refreshZ shown/reset/reselection and success tested; Save422 feedback preserves draft. EditorVM/widget/publicfields165PASS (`/tmp/moliseis-m6-stale-ui.log`). Shared eventModeLocked optional false default preserves public behavior. Operation exclusion/disposal guards cover new commands. Independent UI review pending. Root noticed potential stale visible manual target-ID after candidate selection (constant initialValue-only field); assigned reproduction/minimal hydration fix before7.12; no architecture change.

Root7.4 candidate/target visual inconsistency confirmed and fixed before7.12: screen-owned/disposed target controller synchronizes programmatic selection with mounted guard while retaining raw manual representation if it denotes the selected integer. Widget now proves loaded42→candidate43 updates visible ID43; subsequent manual0044 remains raw and selects44.62widgetPASS (`/tmp/moliseis-m6-target-hydration.log`); root inspected init/dispose/synchronization. No broader navigation/editor refactor.

Task7.12 completed: existing dashboard Fonti ignorate independently lists records without pending; Riattiva fonte uses repository/Command, refreshes ignored and ordinary pending lists, offers returned pending, and keeps failed row reachable with feedback. DashboardVM/widget/Adminrouting35PASS (`/tmp/moliseis-m6-ignored-dashboard.log`). Intermediate test failures were scroll fixture assumptions and base URL after imperative push; final asserts actual editor_8 page, no routing production change. All12M6 tasks implemented, final focused/static/independent review gates in progress beforeM7 authorization.

Root M6 verification:151DenoPASS (`/tmp/moliseis-m6-root-deno.log`), Admin/importer/notification typechecksPASS (`/tmp/moliseis-m6-root-type.log`), real resolutionDB26PASS (`/tmp/moliseis-m6-root-db.log`). Final reviewer found7.12 refresh/un-ignore overlap race: external dashboard loads can start precommit; Command.execute skips required post-success load when already running, allowing stale response to restore ignored row/miss fresh pending. Reopened7.12 for bounded VM exclusion/serialization and delayed overlap regression beforeM6 closure. Target controller fix independently clean; no other finding. No M7 source edits authorized yet.

M6 final: independent reviewer closed7.12 race finding after reading authoritative VM exclusion/drain/postcommit reads and delayed regression;36focusedPASS (`/tmp/moliseis-m6-ignored-race.log`). All previously reported7.1–7.12 findings closed; no material finding remains. Final Flutter429PASS (`/tmp/moliseis-m6-final-flutter.log`) includes Admin models/mapper/repository/all Admin UI/shared publicfields/public submissionVM/Adminrouting; scoped format21files0changes. Scoped analysis has0errors/0warnings and34pre-existing informational diagnostics proven againstHEAD; full default analyzer remainsM9. Root151Deno/26realDB/type gates above remain current; no TS or DB edit after those checks. Main M6 production boundaries Adminmodels/mapper/repository/editor/dashboardVM+UI and optional default-preserving shared field hydration/Event-mode affordance; small Adminwire list/detail/Rejectpending-ID compatibility. No new package/generation/state framework or production routing change. HEAD unchanged, no commit/deploy. Strict/diff final M6 gates run beforeM7.

FinalM6 strict output: Change 'add-external-event-provenance-moderation' is valid (exit0); diffcheck exit0/nooutput. Scoped analyzer was `/opt/homebrew/Caskroom/flutter/3.47.5/flutter/bin/dart analyze` with M6 models/contracts/mapper/repository/Admin UI/sharedfields/focused tests as paths, no --no-fatal-infos flag (Dart analyzer informational default nonfatal). It was not global flutter analyze; M9 global gate remains. M7 now authorized sequentially8.1–8.7 after completeM6.

## M7 — notification isolation and irreversible source assets

Task8.1 completed: appended structural external-ID-null WHEN filter to new undeployedM1 migration (rolloutstep1); applied only new local trigger snippet, not duplicateM1DDL. Transactional dummyVault/pg_net fixture tests imported realLink/Reject enqueue0 and humanEventLink enqueue1 ordinary body, rollback prevents delivery. Root found all-queue counting could race background drainage; fixed to unique dummyURL nonce-scoped counts/body lookup and rerun. No real secrets/email.

Task8.2 completed: authoritative notify select/parser includes provenance; structural skip precedes email claim independent of importerUUIDenv, legacyUUIDdefense retained. Root identified read→claim verified-backfill race; email claim/reclaim UPDATE now external_event_record_id IS NULL conditional. Actual committed legacyaccepted fetch→verifiedbackfill before claim→zero-row/noBrevo/no email-state writes regression passes. NotifyDeno8PASS and real notification/queueDB3PASS (growing external_event_assets_db_test suite). No template/auth/framework changes. Next8.3 atomicassetclaim/irreversibletimestampguard.

Task8.3 completed: new local CLI migration20261002201857_claim_external_event_source_asset.sql provides service-only SECURITY INVOKER/empty-path single-submission-ID RPC, CS→record locks and exclusively persisted imported/pending/unlinked/null-budget/zero-assets guards. No URL/image flag/provider input. Private consistency trigger permits initialNULL→claim/migrationtimestamp and rejects nonnull reset/change. Real DB suite5PASS includes actual overlapping connections one winner, lock-prefix probes, ACL denial, all guard outcomes, token unchanged and budget irreversibility. Generated public/graphql_public Supabase types regenerated from actual local schema. Root inspected completeDDL. Next8.4 Edge eligible-observation orchestration. No deployment.

Task8.4 completed: Edge importSourceAssetIfEligible reuses current provider image allowlist and requires ingest-returned unlinked pending before persisted-state-only one-ID claim. Existing pending_created=false is eligible. Only claimed winner invokes existing upload/add_submission_assets helper; all denial outcomes skip, missing/badimage/linked/nopending make no claim call. ImporterDeno15PASS. Root inspected complete helper/main orchestration; existing cleanup remains. Independent8.1–8.3 reviewer found no material issue, independently notifyDeno8PASS and inspected real DB concurrency/ACL/queue/race regressions without competing fixture execution. Next8.5/8.6 failure/no-retry/removal/overlap proof.

Tasks8.5–8.6 completed with real Edgehelper/PostgREST integration: uploadfailure consumes timestamp and later actual reingest skips; real Link wins inside mocked upload callback, pending-onlyassociation fails, existing Cloudinarycleanup once/orphan removed/claim retained. Two real Edgehelpers overlap yield one upload/asset; real moderator delete_submission_asset followed by ingest cannot restore image; linked updatepending makes no claim; conservative migrated budget currenttimestamp withzeroassets staysconsumed. Real addassets writer holdsCS whileclaim waits then assets_present/no claim. DB11PASS, hard overlappingclaim/ACL/lockprefix/finalization tests retained. No real media upload/delivery. Next8.7 human Link ordinaryacceptednotification realprocessing/onlyBrevo mock.

Task8.7 and finalM7 complete: actual human Link accepted target_event_id/null promoted_event_id passes ordinary notification GET/atomic email claim/mark-sent; only Brevo delivery mocked, recipient/name/city/subject/text/HTML valid and Event/media unchanged. Structural imported suppression and legacy UUID defense have distinct regressions. Root independently ran assets DB12PASS (`/tmp/moliseis-m7-root-assets.log`), existing asset invariants4PASS (`/tmp/moliseis-m7-root-existing-assets.log`), and all four Deno function boundaries155PASS (`/tmp/moliseis-m7-root-deno.log`). Worker scoped type/format/lint gates PASS; reviewer read allM7 changes, no surviving finding. Strict validation output: Change 'add-external-event-provenance-moderation' is valid (exit0); diffcheck exit0/nooutput. Main production changes notification structural trigger/parser/guarded email claim and source-asset RPC/irreversibility trigger/Edge orchestration; no email template change, production delivery, deployment or commit. HEAD remains4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade. Next M8 tooling and local fixtures only; production audit/backfill/freeze/cut-over remain unauthorized and NOT_EXECUTED.

## M8 — audited tooling, fixtures and release gates

Tasks9.1–9.2 complete for exported-data/local preparation: new supabase/tools audit command uses actual production prepareEvent/canonicalizer/hash, strict known notes identity, explicit historical/current duplicates, UTC microsecond handled ordering DESC NULLS LAST/id DESC, statuses/link conflicts/source diagnostics. Shadow comparison is write-free and does not turn moderated fields into provenance; source/editorial/importer transformations need explicit evidence refs, otherwise unresolved. Root independently3PASS (`/tmp/moliseis-m8-audit-shadow.log`); command typecheck/diffcheck workerPASS. README scopes complete historical importer population including parse failures, private exports, source observation evidence and no production execution. Next9.3 own verified snapshots.

Tasks9.3–9.4 local tooling gates complete: verified captures require own submission ID, exact source identity, verified_source_capture origin and nonempty evidence reference; canonical tuple/hash never uses moderated legacy fields. Gate includes every exported pending, including malformed notes/omitted snapshot evidence, rejects duplicate exported IDs and cannot waive strong-identity/Event/source conflicts. Root independent5PASS (`/tmp/moliseis-m8-snapshots.log`); earlier attempted run during a live edit had transient missing-export typecheck failure, no PASS was claimed and stable checkpoint rerun passes. Production ambiguity remediation is NOT_EXECUTED; gates fail closed until evidence/remediation is supplied. Next9.5 classification/backfill.

Task9.5 complete in local preparation: seven closed classifications with explicit evidence/authorizations, last-handled binding, unavailable-source evidence and retain-legacy branch; null proposed only verified_unhandled. Contradictory own handled capture/watermark, unverifiable baseline carrying verified latest capture and accepted Place history fail closed. Root independent7purePASS (`/tmp/moliseis-m8-root-classes.log`) and5realDBPASS (`/tmp/moliseis-m8-root-backfill.log`). Privileged one-shot backfill locks allCS→allrecords→allEvents, validates complete SQLJSONB export/6microsecond drift and record JSONB/hash/version/link state, preserves moderated content/status/links/Event/media, fills only verified tuples, consumes conservative pending image budget and reuses sole enqueue; rollback and replay demonstrated. Root-found timestamp-shaped plaintext bug fixed by restricting conversion to named temporal columns; regressionPASS. SQLJSONB export boundary documented to avoid PostgREST double rounding false drift; no second SQL canonicalizer. No production execution/schema changes/public migration API. Operational command and production-ingest dry-run remain next9.6 gates.

Independent review reopens9.5: audit correctly reports provider adapter failures but planner does not yet reject them, allowing incomplete observations to be misclassified as unavailable/current. P2 implementation fail-closed gap, not an OpenSpec contradiction. Halt laterM8task progression until invalid-only and valid+invalid duplicate observations fail planner tests; root will rerun relevant gates before rechecking9.5.

9.5 review gap closed: latest upstream gate rejects parse/observation failures before classifications; root8purePASS includes invalid-only and valid+invalid duplicate attempts with explicit absence refs, reviewer confirms no surviving9.5finding. Root latest real migrationDB7PASS (`/tmp/moliseis-m8-root-dryrun.log`) includes actual production-ingest rollback/explained proposals and separate strong identities despite identical semantic fields. 9.6 remains unchecked: reviewer found committing CLI only validates T0 before awaited dryrun, so clock crossing Rome midnight could apply stale audit; add after-dryrun and precommit guards with controlled-clock regression before later task progression. Configured ingest seed UUID will be env-only, matching runtime. No architecture contradiction or production execution.

Tasks9.6–9.7 complete in local preparation: actual public.ingest_external_event runs within rolled-back verified backfill dryrun; each pending must have a distinct handled watermark and exact identity/hash/evidence explanation, otherwise rollback. Explicit migrate_external_events command defaults to --plan/NOT_EXECUTED; --apply requires release evidence, original quiescentT0 sameRomeDate, preflight actualingest dryrun, after-dryrun date recheck and guarded transaction precommit recheck. Configured EXTERNAL_EVENTS_IMPORTER_USER_ID env is passed only to ingest, manifest identity rejected, --plan env-free. Root9pure/CLItoolsPASS (`/tmp/moliseis-m8-root-tools.log`),8realDBPASS (`/tmp/moliseis-m8-root-dryrun.log`) includes controlledclock crossRomeMidnight after attempted writes→fullrollback and separate IDs samecity/name/day→distinct proposals. Reviewer confirms all9.1–9.7 findingsclosed. Strictvalid/diffcheckPASS. No production audit/backfill/activation, commit or deployment. Next9.8 realdrift/editorial baselines.

Task9.8 complete locally: explicit reconciliation AND source-baseline authorization required for unverifiable accepted realdrift; no verified-handled/null-base workaround. Actual SQL editorialbaseline current=proposed links unambiguous historical Event, leaves accepted row structurallylegacy and byte-for-byte unchanged, creates no pending/Eventwrite. Root9migrationDBPASS (`/tmp/moliseis-m8-root-baselines.log`), tools11PASS (`/tmp/moliseis-m8-root-tools.log`, includes next-task fixture already present;9.9 not yet certified). Workerreported scoped10PASS before next fixture. No production remediation/audit executed. Next9.9 rejected/ignored/absent states.

Task9.9 locally complete: observable rejected baseline and explicitly authorized ignoredbaseline have current=proposed/non-nullwatermark; actual SQL preserves unverifiable rejected row structurallylegacy/byte-for-byte. Verified unavailable source with handledsnapshot has current=proposed=snapshot; explicit absence without verifiedsnapshot creates no record and retainslegacy. Missingabsence/authorization blocks. Root12migrationDBPASS (`/tmp/moliseis-m8-root-baselines.log`), tools11PASS remains current for these fixtures. Production classification remainsNOT_EXECUTED. Next9.10 exported-data report/localproof and production reporttemplate.

Task9.10 tooling/report portion implemented and locally verified: exported-data gate report includes exact unresolved counts, total classifications/evidence refs, full-population reference and explicit fixture/production_export label; no mismatch-percentage bypass. Production template keeps unknown counts null and audit/backfill/cutover/production-contract dryrun NOT_EXECUTED. Root13toolsPASS (`/tmp/moliseis-m8-root-tools.log`), inspected report/template and CLI gates. Task9.10 remains unchecked for actual production audit/report proof, which user excludes from this implementation authorization; fixture zero counts are not production zero counts. This release obligation does not authorize production operations or prevent preparing9.11–9.12/localM9 tests. Next explicit normalization-version migration procedures/fixtures.

9.10 local tooling review found --plan regenerated plans before emitting its computed failed report, losing diagnostics for invalid observations/missing captures. Fixed branch emits rich JSON false-gate report and exit1 without DB/env access; actual Deno child-process regressions verify both cases. Rootalltools16PASS (/tmp/moliseis-m8-root-tools.log; flags --allow-env --allow-read --allow-run=deno --allow-write=/tmp). 9.11 procedure/policy fixtures locally pass: future approved shared TS converter owns complete shapes/hashes; offline policy only accounts current/proposed/everypending, preserves divergence/nullbase, refetch baseline only oldaccounted, blocks unconvertible proposed/pending. No v2 runtime/profile/converter/hash implementation/API. Root identified late trigger-DDL table-lock upgrade hazard; official PG17 ALTERTABLE documentation confirms DISABLE/ENABLETRIGGER SHARE ROW EXCLUSIVE, so procedure obtains that submission-table lock first before row/record/Event locks, drains manual/scheduled/in-flight ingest, targets only provenance trigger and re-enables before commit. Final independent9.10fix/9.11review pending before9.12. No production operations.

Independent9.10diagnosticfindingclosed and9.11reviewclean: actual --plan subprocess proves failedgateJSONbeforeenv/DB; bounded offlineversionpolicy/procedure alignsclosednormalizationcontract. Root16toolsPASS remains executionevidence;9.11checked,9.10actualproductionreport remainsunchecked/NOT_EXECUTED. No runtimev2/API/SQLconverter introduced. Next9.12 legacyimagebudget fixturegate.

Task9.12 and finalM8 local gates complete: actual legacy upload/remove, failed attempt and unknown-history fixtures consume migration-time source asset budget; only positive never-attempted evidence preserves eligibility. Replay/removal/reingest prove no restoration. Root independently reran16migrationDBPASS (/tmp/moliseis-m8-root-final-db.log),17toolsPASS (/tmp/moliseis-m8-root-final-tools.log),4typechecksPASS, fmt15/lint11PASS. Last duplicate-pending upfront gate regression independently reviewed clean. Strict output: Change 'add-external-event-provenance-moderation' is valid (exit0); git diff --check exit0/nooutput. 88/98 tasks checked;9.10 actualproductionreport remains NOT_EXECUTED/unchecked. HEAD unchanged4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade; no commit/deploy/productionaudit. M9 local verification/runbook now authorized sequentially.

## M9 — final local verification and release preparation

Root initialM9 checks:210DenoPASS (/tmp/moliseis-m9-deno.log; shared/importer/Admin/notify/submit-content/tools), fullFlutter1772PASS+2opt-in skipped (/tmp/moliseis-m9-full-flutter.log), existing all-day opt-in separately1PASS (/tmp/moliseis-m9-all-day-e2e.log). Default flutter analyze --no-pub exit1:177diagnostics,0errors,4samebaselinewarnings,173infos (/tmp/moliseis-m9-full-analyze.log), versus M0baseline178/0/4/174; no new warning. Generated Supabase types fromactualschema compareidentical afterDenoformat and ignoring generator identifier-property quotation only; sourcegeneratedfileunchanged by check. Freshforwardreplay requested only ondisposable553xxstack with12currentmigrations/no seed/no secrets copied; CLIdefaultuncachedimage startupblockedprecontainer, retry withcachedPG17.6.1.127/Auth/RESTimage overrides pending. Existinglocalstack untouched. NewtokenE2E/runbook final gates inprogress; no production operations/commit.

Task10.1 PASS: all12migrationfiles applied fromzero ondisposablePG17.6.1.127/Supabase stack553xx, then11DBsuitefiles165PASS:temporal6/assets12/ingest23/migration16/moderation20/provenance9/resolution26/existingassets4/idempotency11/promotion37/allDayREST1. Logs /tmp/moliseis-m9-fresh-*_test.log. Startupblock wasDockercredential-desktop helper, resolved onlyfor thischildprocess withtemporaryemptyDOCKER_CONFIG/localDockerHost andcachedimages; userDockerconfig/originalstack unchanged. Task10.4 rootactualE2E1PASS (/tmp/moliseis-m9-root-token-e2e.log), independentreviewclean; lastnewfixturelintno-unsafe-finally undercorrection beforecertification. BroaddefaultDenoLint baseline independentlyreproduced fromgitHEAD:14historicalfindings (3unversionedimports,1unusedtypeimport,10requireawaittests), current15includes1newfixturefinding tofix; baseline production untouched.

Tasks10.2–10.4 final local acceptance:212DenoPASS (/tmp/moliseis-m9-final-deno.log),40touchedTSfiles typecheck/fmtPASS (/tmp/moliseis-m9-final-types.log,/tmp/moliseis-m9-final-fmt.log),defaultDenoLint14exactbaselinefindings only (baseline source checked fromgitHEAD); newfixture unsafe-finally fixed and scopedlintPASS. FullFlutter1772PASS+3opt-in skips (/tmp/moliseis-m9-final-full-flutter.log); allDay1PASS and token1PASS separatelyactualopt-in. Flutter analyze --no-pub exit1 with177diagnostics/0errors/4samebaselinewarnings/173infos (/tmp/moliseis-m9-final-analyze.log), no change-attributablewarning; focusedM6suite429PASS andnewDartbridge/testanalyzeNoissues. RawtokenE2E proof actualAuth→Dartrepository→productionAdminhandler/store→SQL, exactrawStringHTTPpreview/body/6microequality,1microdrift0mutation, JWTAdmin!=technicalimporter, lostcommittedresponse samepreviewAlreadyResolved/unchangedstate. Rootindependent1PASS /tmp/moliseis-m9-root-token-e2e.log; finalcleanupfixture1PASS /tmp/moliseis-m9-token-e2e-final.log; independentreviewclean. FreshschemaactualRLS=true; anon/authenticated tableSelect/ingest/claim=false,serviceRole=true;12recordedmigrations. Finalscope/runbookreview/strictdiff gates next. Production9.10/10.8 stillNOT_EXECUTED/unchecked.

Final M9 local certification:10.5/10.6/10.7/10.9 complete. Independent final runbook/token/ACL review has no surviving material finding. Eight-step runbook and evidence-only prefreeze helper require client update/ignore/stale paths BEFOREfreeze; stagedprefix avoids deploying M4outcome before compatibleAdminmapping; latequeued/manual syntheticrequests drain before rawmicrosecondT0, sameRomeDate expiry abandons staleaudit, postcutoverrollback retainsprovenance and neverrestoreslegacy. Rootfreshrollout1PASS (/tmp/moliseis-m9-fresh-external_event_rollout_db_test.log), total12DBfiles166PASS, preflight2included212DenoPASS. LatestfourM9TSfmt/lint/type/bashsyntaxPASS. Scoped source review confirms onlyexternal_event_records newtable, singleTScanonicalizer/noSQLcanon, no newpackage/framework/sourceCMS/revisionledger/status/removal/relink/media-update/Eventrestore/pg_trgm; threeM0unrelatedfilespreserved. Generatedschema comparison/actualRLS/grants reviewed. Strict final output: Change 'add-external-event-provenance-moderation' is valid (exit0). git diff --check exit0/nooutput;49untrackedfiles additionalwhitespacecheck0diagnostics (initial harness mistook no-index normaldiff exit1 forfailure; correctedinterpretation rerun0diagnostics). Disposable553xxstack stopped/removed successfully, original543xxstack remainshealthy. HEAD unchanged4b661b8d0fe83a7e28c9983eb04e4b8a561f7ade; no commit/push/archive/productiondeploy/audit/freeze/backfill/cutover.

Status:96/98tasks checked. 9.10 actualproduction zero-conflict audit/cutoverreport and10.8 actualproduction writerfreeze/drain/quiescence/T0 remain NOT_EXECUTED/unchecked under explicit no-production-release authorization. Tooling/localrehearsals are ready; this is not a declaration that the entire Workstream or release is complete. No open architectural decision or remaining local implementation blocker identified.


## Production rollout — 2026-10-03 and subsequent smoke/E2E

This append-only final account records production evidence supplied by the
operator for this post-cutover remediation. The earlier `NOT_EXECUTED`, unchecked
9.10/10.8 and 96/98 entries remain accurate historical checkpoints: implementation
verification ended before production authorization. Tasks 9.10 and 10.8 were
completed subsequently during the real authorized rollout, explaining their
checked state in the archived `tasks.md`. This section is the final
post-deployment account; the remediation itself did not query or change
production. No missing cutover timestamp, private evidence reference or manual
canary date is inferred.

### Release boundary and permanent legacy retirement

Baseline/release commit: `d24af726c6e124dff91537d0add7c011ef1209bc`.

T0: `2026-10-03T20:48:51.682622+00:00`.

- Cron `import-external-events-eventimolise` was unscheduled.
- The legacy `import-external-events` Edge route was retired before migration.
- Queued/in-flight invocations were drained and writer quiescence was verified
  before T0.
- Provenance cutover was subsequently executed. After that boundary,
  `legacy_writer = PERMANENTLY_RETIRED`; the legacy writer must never be restored.
  Its exact cutover timestamp was not supplied and is not invented here.

### Legacy remediation, classification and verified backfill

During authorized remediation, 32 unpromoted legacy pending submissions were
removed. The final classified legacy population was 18: 17 accepted, one
rejected, zero pending. All 17 accepted submissions were linked one-to-one to
canonical Events. Classifications were 17 `editorial_baseline` and one
`rejected_baseline`. There were zero ambiguous pending, zero identity/link
conflicts and zero unexplained mismatches.

The backfill report recorded:

```text
execution = VERIFIED_BACKFILL_APPLIED
production_cutover = NOT_EXECUTED
classified_records = 18
explained_pending_proposals = 0
```

`production_cutover = NOT_EXECUTED` is the backfill report's state at that stage,
not the final rollout state. The provenance cutover occurred subsequently.

Post-backfill verification recorded:

```text
records = 18
linked_events = 17
invalid_current_state = 0
null_watermarks = 0
watermark_differences = 0
```

### Provenance-aware importer activation

Production Edge Function `import-external-events` was ACTIVE, version 1 after
delete/recreate. Deployment was observed at `2026-10-03 21:24:35 UTC`.
`verify_jwt = false`, authentication uses `x-import-secret`, and source writes
use `ingest_external_event`.

Production cron was `import-external-events-eventimolise-provenance`, schedule
`0 22,23 * * *`, `active = true`. This is distinct from the retired legacy job.
The provenance cron is operator-managed and intentionally not created by schema
migrations; its executable definition is versioned in the release runbook. The
post-cutover retirement forward migration removes the historical legacy job on
fresh replay without activating the provenance cron.

### Subsequent manually verified production canary

The operator subsequently verified this real smoke/E2E canary manually. No
canary timestamp was supplied. Provider/source identity:

```text
provider = eventimolise
external_id = 18871
```

Ingest produced `external_event_record_id = 191` and
`content_submission_id = 351`, initially `pending`. Its immutable snapshot hash
matched the current source hash. Source asset claim/upload yielded:

```text
asset_id = 278
width = 723
height = 1024
mime_type = image/png
```

There were zero external event records with more than one pending submission.
Admin correctly loaded the submission as an external Event proposal and showed
the current source snapshot. The initial category was `unknown`; publication
readiness was correctly blocked until category selection and Save.

After a category was assigned, **Pubblica come evento** completed successfully:

```text
submission 351:
  status = accepted
  promoted_event_id = 43
  target_event_id = NULL
record 191:
  event_id = 43
  moderation_hash = proposed_hash
  normalization_version = proposed_normalization_version
follow-up pending = none
```

The verified flow was:

```text
EventiMolise
→ provenance ingest
→ immutable submission snapshot
→ source asset claim/upload
→ Admin moderation
→ canonical Event publication
→ source/Event linkage
→ watermark advancement

PRODUCTION E2E: PASS
```

Link to an existing Event and source-update/three-way-merge were **not** exercised
manually in production by this canary. They remain covered by the existing
automated tests described above; this account does not convert automated
coverage into a manual production verification claim.
