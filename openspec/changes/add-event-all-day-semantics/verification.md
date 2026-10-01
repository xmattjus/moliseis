# Implementation evidence

Execution HEAD: `d7f747782b7ab924111b96f906599c28917c64d6`, descendant of the reviewed
planning baseline `3706d1b131c2cdb6d6213fd1db56fb1e5b8cc8b8`. Initial working tree
was clean. The intervening commit changes agent routing, not application behavior.

## M1

- The new mode cases failed against the preceding validator before implementation.
- Shared, public and Admin validator tests: 41 passed.
- Public handler tests: 9 passed, including invalid replay input before writes.
- Shared normalization tests also passed under UTC, America/Los_Angeles and
  America/New_York runtime timezones.
- Deno type checking and formatting passed for the changed M1 modules.

## Compatibility evidence captured before Flutter changes

- `previous_event_decoder_compatibility_test.dart` passed against the unchanged
  Event DTO/mapper at execution HEAD with an extra remote `all_day=true` field.
  This proves representative preceding decoder tolerance, not certification of
  a published application artifact or its startup/sync behavior.
- A real previous-model ObjectBox store was written, closed and captured in
  `test/fixtures/objectbox/pre_all_day/` before generator inputs changed. Its
  README identifies the producer model, checksum and historical event/draft rows.
  Reopening this fixture with the evolved model remains a separate gate.
- Baseline `flutter analyze` completed with 178 existing diagnostics (174 infos and four warnings). Final analysis must be compared without unrelated lint cleanup.

## M2

- Created forward migration `20261001175539`; existing migrations were preserved.
- Backed up the freshly started local database, reset locally to
  `20260929202015`, seeded historical midnight rows, and applied the forward
  migration. Both modes defaulted false and timestamp values were unchanged.
- Affected DB runners passed: temporal invariants 5/5, server idempotency 11/11,
  promotion 37/37.
- `run_submission_all_day_postgrest_test.sh`: 1/1 passed using actual local Auth,
  PostgREST and PostgreSQL. Omitted/default-false and explicit-true argument sets
  dispatched correctly, exact dates survived, and anon/authenticated execution
  was denied. No compatibility wrapper was needed.
- Shared/public/Admin Deno suites: 90/90; independent reviewer rerun also 90/90.
- `deno fmt --check` (19 affected files), handler/smoke `deno check`, runner
  `bash -n` and `git diff --check` passed.
- Regenerated database types using
  `supabase gen types --local --schema public,graphql_public`. Identifier syntax
  was normalized mechanically to the existing style. Semantic additions are
  the six table-mode projections and optional RPC flag; Deno formatter changes
  account for the remaining utility-type formatting diff.
- Local security advisors at error level reported no issues. Expected missing
  Vault configuration warnings did not affect the affected tests.
- Backend adversarial review found no material defect after tracing validation,
  stores, constraints, ACL, replay, rollback and locked promotion. Main also ran
  `deno check` for both handlers and the real PostgREST test successfully.

Local verification only. No deployment or commit is authorized by this record.

## Current-time consumer audit

Targeted searches of SQL migrations, Edge Functions and Dart event paths found
no consumer that expires an event by comparing its start-only timestamp with
the current instant. The concrete current-time paths are:

- `EventRepositoryImpl.getNextEventIds`: Rome-day start through the inclusive
  thirtieth day, ordered by start and limited to six; no end-based expiration.
- `ObjectBoxConditions.visibleEventInCurrentYear` and search consumers: inclusive
  Rome-year overlap, including single-day membership.
- `EventViewModel`: current Rome calendar selection and civil-day membership.
- Public date picker: bounds and initial clock selection, not event expiration.
- Importer dedup: source-date bounds, independent of current time.

Other `now` usages concern sync scheduling, modification markers, weather,
uploads or notification retry age. No effective-end correction is indicated.
Representative new-shape discovery tests remain required in M6.

## Generated model inspection

Main compared every existing entity/property ID and UID in the evolved
ObjectBox model against the captured preceding model: no changes. Additions
are exactly `EventEntity.allDay`, `ContentSubmissionDraftEntity.allDay` and
`ContentSubmissionDraftEntity.pendingEndCalendarDate`. The genuine preceding-store
reopen/write regression passed in M3.

## M3

- `build_runner build --delete-conflicting-outputs` generated the DTO mapper and
  ObjectBox outputs from changed inputs; no manual generated edits.
- Focused temporal/model/mapper/draft/repository suites: 151 passed initially.
  After final adjustments, policy/draft/previous-store suites 29 passed and
  mapper/wire/event-repository suites 115 passed.
- Independent public/Admin repository validation: 52 passed, including exact
  17-key public and 12-key Admin envelopes and immutable request capture.
- Genuine preceding-store reopen passed with historical false, original dates,
  draft identity and `isSaved`; all-day and unresolved timed checkpoints then
  round-tripped through the same evolved real store.
- Real-ObjectBox `prepareSync`/`commitSync` regression adopted a flag-only remote
  update while retaining saved state. Updated DB temporal runner: 6/6 passed,
  including real `modified_at` advancement on a flag-only update.
- Main final `flutter analyze`: 178 diagnostics, matching the baseline count;
  no new errors/warnings. New informational diagnostics were corrected only in
  changed files. Exit 1 reflects the existing diagnostics.
- Main scoped diff and `git diff --check` passed. M3 accepted.

## M4

- Seven public/Admin ViewModel, widget and rendering suites: 304/304 passed.
- UTC-backed DST all-day/timed-midnight regression under
  `TZ=America/Los_Angeles`: 1/1 passed; grid/card/search integrations for both
  modes under the same timezone: 6/6 passed.
- Admin widget suite with explicit restored-true hydration: 41 passed. The
  fixture uses the existing explicit-load lifecycle of the screen.
- Focused analyzer reported existing diagnostics only; `git diff --check`
  passed. No async flow was rewritten.
- Direct start-time rendering audit found one shared formatter,
  `EventFormattedDateTime`, used by `ContentSliverGrid`,
  `ContentEventCardGridItem`, `SearchAnchorSuggestionList` and
  `PostSectionHeader`. The public fields clock picker is the editor seam.
- The broad renderer suite contains existing device-local fixture assumptions;
  foreign-timezone checks use explicit UTC-backed inputs so the event instant
  remains identical. No production workaround or unrelated fixture rewrite.
- Intermediate adversarial M3/M4 review found no material defect in transitions,
  pending dates, recovery, immutable capture, defaults, saved-state merge, Admin
  guards or rendering. Independent policy/draft/previous-store/DTO/renderer
  selection: 43/43 passed.

## M5

- Importer Deno suites (`import_logic_test.ts`, `eventimolise_test.ts`,
  `index_test.ts`): 19/19 passed; formatting and type checks passed.
- Source fixtures cover date-only single/multi-day across DST, meaningful time,
  mixed final-date precision, real midnight timed and invalid civil input with
  zero writes. They exercise the actual direct-insert payload helper.
- Prepared events retain the existing normalized-UTC shape plus one mode flag.
  Source-owned normalization runs while preparing that shape and is validated
  again by the shared temporal boundary before persistence. Only persisted
  `all_day`, `start_date`, `end_date` are emitted; civil fields are not columns.
- Contract review confirms the future-provider fixture shapes need no further
  DB/domain contract. EventiMolise remains false with unchanged optional-end and
  Rome-day dedup behavior. No live provider/framework or second broad E2E.

## M6 final verification

Representative discovery plus existing event/search/policy suites: **80 passed**.
Single-day, multi-day, cross-year, DST, start sorting and upcoming are covered
without production query changes or a new filter matrix.

The single broad E2E passed **one test covering three cases** (all-day single,
all-day multi and timed legacy) using actual local Auth/PostgREST/PostgreSQL:

```sh
MOLISE_ALL_DAY_LOCAL_E2E=1 /Users/benitomatteobercini/Development/flutter/bin/flutter test test/integration/all_day_pipeline_test.dart
```

It traverses edited state and immutable captured wire input, the shared public
normalizer, atomic `submit_content`, promotion, remote event fetch, DTO,
ObjectBox/domain and Rome rendering. The existing Admin full-input boundary
adds only coordinates before promotion because the public editor does not own
coordinates. Mode/dates remain identical, including SQL microsecond equality.
Native filesystem/process I/O runs through `tester.runAsync`. Fixtures use
unique local users/cities and clean up after execution. Normal Flutter suite
runs skip this explicit local integration; the gate above was actually run.

Main combined affected Deno run: **109 passed, 0 failed**.

```sh
deno test --allow-env \
  supabase/functions/_shared/submission_dates_test.ts \
  supabase/functions/submit-content/submission_validation_test.ts \
  supabase/functions/submit-content/submission_store_test.ts \
  supabase/functions/submit-content/index_test.ts \
  supabase/functions/admin-content-submissions/admin_submission_validation_test.ts \
  supabase/functions/admin-content-submissions/admin_submission_store_test.ts \
  supabase/functions/admin-content-submissions/index_test.ts \
  supabase/functions/import-external-events/import_logic_test.ts \
  supabase/functions/import-external-events/eventimolise_test.ts \
  supabase/functions/import-external-events/index_test.ts
```

Main `deno fmt --check` on all 23 changed TypeScript files passed. Main
`deno check` on public/Admin/importer handlers and both local bridges passed.

Final affected local DB commands all passed:

```sh
bash supabase/tests/run_event_temporal_invariants_db_test.sh    # 6/6
bash supabase/tests/run_submission_idempotency_db_test.sh       # 11/11
bash supabase/tests/run_submission_promotion_db_test.sh         # 37/37
bash supabase/tests/run_submission_all_day_postgrest_test.sh    # 1/1 actual dispatch
```

Final Flutter verification, executed sequentially by the test debugger:

```sh
/Users/benitomatteobercini/Development/flutter/bin/flutter test --reporter expanded
/Users/benitomatteobercini/Development/flutter/bin/flutter analyze
```

- Full suite: **1703 passed, 2 skipped**, exit 0. Skips are the explicit local
  E2E (run separately above) and the pre-existing geo-map navigation regression
  disabled for upstream issue `#188018`.
- Analyzer: **178 diagnostics = 174 infos + four warnings, zero errors**. The
  line-normalized diagnostic multiset exactly matches the execution baseline;
  main independently confirmed the equality. Exit 1 is pre-existing.
- Final adversarial review of the whole diff: **no material findings**. It
  independently checked ObjectBox definitions/UIDs, historical fixture,
  importer writer/fixtures, real E2E and preserved queries, as well as the
  previously reviewed backend and draft/UI paths. No review remediation remains.

## Final closure

- Strict OpenSpec validation: `Change 'add-event-all-day-semantics' is valid`.
- `git diff --check`, both new runner syntax checks and baseline ancestry passed.
- Main independently compared every preceding ObjectBox property definition and
  UID: unchanged.
- No dependency, application configuration, unrelated refactor, canonical or
  archived spec, adjacent Admin change, forced-update/version-routing, live
  provider, half-open or upcoming changes.
- All **33/33** tasks have evidence; no blocker or unresolved review finding.
- HEAD remains the execution HEAD; no commit or deployment performed.

Final `git status --short`:

```text
 M lib/data/data-sources/content_submission_draft_entry.dart
 M lib/data/data-sources/event_entity.dart
 M lib/data/dtos/event_dto.dart
 M lib/data/dtos/generated/event_dto.mapper.dart
 M lib/data/mappers/admin_submission_mapper.dart
 M lib/data/mappers/content_submission_draft_mapper.dart
 M lib/data/mappers/content_submission_wire_mapper.dart
 M lib/data/mappers/event_dto_mapper.dart
 M lib/data/mappers/event_entity_mapper.dart
 M lib/domain/core/event_time.dart
 M lib/domain/models/admin_submission.dart
 M lib/domain/models/admin_submission_input.dart
 M lib/domain/models/content_submission.dart
 M lib/domain/models/event.dart
 M lib/generated/objectbox-model.json
 M lib/generated/objectbox.g.dart
 M lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart
 M lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart
 M lib/ui/content_submission/view_models/content_submission_view_model.dart
 M lib/ui/content_submission/widgets/content_submission_fields.dart
 M lib/ui/content_submission/widgets/content_submission_screen.dart
 M lib/ui/event/widgets/components/event_formatted_date_time.dart
 M openspec/changes/add-event-all-day-semantics/tasks.md
 M supabase/functions/_shared/database.types.ts
 M supabase/functions/_shared/submission_dates.ts
 M supabase/functions/_shared/submission_dates_test.ts
 M supabase/functions/admin-content-submissions/admin_submission_store.ts
 M supabase/functions/admin-content-submissions/admin_submission_store_test.ts
 M supabase/functions/admin-content-submissions/admin_submission_validation.ts
 M supabase/functions/admin-content-submissions/admin_submission_validation_test.ts
 M supabase/functions/admin-content-submissions/index.ts
 M supabase/functions/admin-content-submissions/index_test.ts
 M supabase/functions/import-external-events/import_logic.ts
 M supabase/functions/import-external-events/import_logic_test.ts
 M supabase/functions/import-external-events/index.ts
 M supabase/functions/import-external-events/index_test.ts
 M supabase/functions/submit-content/index_test.ts
 M supabase/functions/submit-content/submission_store.ts
 M supabase/functions/submit-content/submission_store_test.ts
 M supabase/functions/submit-content/submission_validation.ts
 M supabase/functions/submit-content/submission_validation_test.ts
 M supabase/tests/event_temporal_invariants_db_test.ts
 M supabase/tests/submission_idempotency_db_test.ts
 M supabase/tests/submission_promotion_db_test.ts
 M test/data/mappers/admin_submission_mapper_test.dart
 M test/data/mappers/content_submission_draft_mapper_test.dart
 M test/data/mappers/content_submission_wire_mapper_test.dart
 M test/data/mappers/event_dto_mapper_test.dart
 M test/data/mappers/event_entity_mapper_test.dart
 M test/data/repositories/admin_content_submission_repository_impl_test.dart
 M test/data/repositories/content_submission_repository_impl_test.dart
 M test/data/repositories/event_repository_impl_test.dart
 M test/domain/core/event_time_test.dart
 M test/support/fake_repositories.dart
 M test/support/fixtures.dart
 M test/support/objectbox_test_store.dart
 M test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart
 M test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart
 M test/ui/content_submission/view_models/content_submission_view_model_test.dart
 M test/ui/content_submission/widgets/content_submission_fields_test.dart
 M test/ui/core/ui/content/event_formatted_date_time_integration_test.dart
 M test/ui/event/widgets/components/event_formatted_date_time_test.dart
?? openspec/changes/add-event-all-day-semantics/rollout.md
?? openspec/changes/add-event-all-day-semantics/verification.md
?? supabase/migrations/20261001175539_add_event_all_day_semantics.sql
?? supabase/tests/all_day_e2e_fixture.ts
?? supabase/tests/run_all_day_e2e_fixture.sh
?? supabase/tests/run_submission_all_day_postgrest_test.sh
?? supabase/tests/submission_all_day_postgrest_test.ts
?? test/data/all_day_previous_store_test.dart
?? test/data/mappers/previous_event_decoder_compatibility_test.dart
?? test/domain/models/all_day_models_test.dart
?? test/fixtures/
?? test/integration/
```
