## Context

See proposal.md for motivation. Planning audited local and remote `main` at `8d7724960889a4224c11f8a2c58d31d8c1c945c7`; remote HEAD matched the supplied baseline, and no pre-existing work was present. Only this change's planning artifacts are written now. Remediation audited local and remote `main` at review commit `18ff4ff09427b7675750639d646e32bc68adbf9f`; the change is intact and production files are unchanged from the original planning baseline.

Repository evidence:

- `lib/domain/use-cases/sync_use_case.dart` prepares four repositories concurrently through record `.wait`, then commits cities, places, events and media in one coordinator transaction. It ignores the Result returned by `setModifiedAt`. `lib/data/core/objectbox_sync_transaction_coordinator.dart` converts an error Result to a thrown transaction sentinel so ObjectBox rolls back.
- `lib/utils/synchronizable.dart` and `lib/data/core/base_sync_repository.dart` define two-phase sync. Four `lib/data/repositories/*_repository_impl.dart` implementations use unpaged `.select()`. Base merge handles tombstones before freshness, setting only `isDeleted` and retaining the old marker. All production subclasses are the four canonical repositories; `supportsSoftDelete` has no other production consumer.
- `lib/data/mappers/{event,place,media}_dto_mapper.dart` already map deletion in create and merge. Their `copyWith` preserves non-remote state including Event/Place `isSaved`. City mapper omits deletion in both paths. Full-row DTO decoding already preserves explicit-null versus absent relation semantics; keep it.
- `lib/data/data-sources/app_settings.dart` stores singleton ID 1; `lib/generated/objectbox-model.json` identifies entity `6:8898619296747710534`, with last property `10:398867547277998639` (`lastSyncedAt`, dateNano). `SettingsRepositoryImpl._persistNewSettings` changes its cache only on successful save.
- `SyncViewModel` classifies sync failure as fatal using `lastSyncedAt == null`, and triggers automatic sync through `isSyncRequired`. `config/dependencies.dart` constructs the coordinator inline. Preserve the legacy Command used by this existing ViewModel; command migration is unrelated.
- Schema/old triggers/RLS are in `supabase/migrations/20260822113151_remote_schema.sql`; category is present there and Event `all_day` is added by `20261001175539_add_event_all_day_semantics.sql`. Canonical markers are NOT NULL with default `now()`. The four `handle_modified_at` triggers use moddatetime only when `deleted_at` is unchanged.
- Latest promotion and external Event apply RPCs are in `20261002181549_resolve_external_event_submissions.sql`; ingest is in `20261002172057_ingest_external_events.sql`. Canonical client writes, including DELETE, are denied by RLS; SELECT includes tombstones. No productive hard-delete or canonical restore workflow was found in Flutter/Edge Functions. Test teardown hard-deletes are fixtures, not runtime features.
- Client startup attempts anonymous authentication but continues after AuthException (`lib/main.dart`, `lib/data/services/supabase_anonymous_session.dart`). Retrieval can therefore use `anon` as well as `authenticated` (including anonymous authenticated users). Both roles need cursor RPC access.
- Local dependency source confirms postgrest 2.9.1 has `gte`, `gt`, `order`, `limit`; locked ObjectBox is 5.3.2. Supabase config uses PostgreSQL 17. No dependency upgrade is needed.

No semantic-field discrepancy exists. Media SQL `description` maps to DTO/entity `title`; City SQL `description_delta` is currently not exposed by City DTO/entity. Retain the database semantic field in the trigger but do not add City description presentation/model scope. No canonical sync capability exists; local-content-retrieval covers discovery, so the dedicated capability is justified.

## Goals / Non-Goals

**Goals:** optimize remote retrieval with an executable protocol; maintain atomic content publication and reliable cursor authority; support existing installed caches and backend-first rollout.

**Non-Goals:** all exclusions in proposal.md apply. This is not a transactionally ordered replication system or a multi-request snapshot. No changes to submission/source-marker semantics, Event restore workflow, local discovery, Command architecture, or DI framework.

## Decisions

### D1 — Explicit semantic markers and ordered legacy repair

The contract is: “modified_at represents the last semantically relevant change to the resource represented by the row. Which changes are semantically relevant is table-specific and must not be interpreted as every SQL UPDATE.”

The migration MUST leave this principle in persistent DB metadata using `COMMENT ON COLUMN` for exactly `public.cities.modified_at`, `public.events.modified_at`, `public.places.modified_at` and `public.media.modified_at`. Use: “modified_at identifies the last semantically relevant change to the resource represented by the row. Which changes are semantically relevant is table-specific and must not be interpreted as every SQL UPDATE.” Add that deleted_at lifecycle changes, including soft-delete and return to active, are semantic for these canonical tables. SQL inline comments can supplement, but cannot replace, these column comments. Do not add this comment to content_submissions or external_event_records or change their marker contracts. Verify the four comments through catalog inspection after migration.

`created_at` is immutable metadata for all supported canonical runtime writers. It remains client-visible and used in local ordering, but is excluded from the semantic predicate because supported producers never update it. Manual/privileged corrections outside supported runtime paths are outside the replication contract. Do not add a created_at guard trigger, CHECK, other enforcement infrastructure or include it in the predicate. Current latest promotion creates Event/Place/Media without assigning created_at, and external Event apply updates only semantic groups (`20261002181549_resolve_external_event_submissions.sql`); current ingest/Edge/Flutter paths do not mutate canonical created_at. M1 must re-audit current canonical writers and stop/report a contradiction if any supported writer does modify it.

The restore-capable persistence/sync contract recognizes deleted_at non-null → null, strictly advances its marker and represents the active row locally. Generic marker triggers and low-level DB/mapper/sync tests cover this capability. As clarified by the external-event-provenance-moderation delta, it introduces no supported Event restore operation: no restore RPC, Admin command/UI, moderation workflow, restore-performing trigger or new runtime producer. Do not modify provenance enqueue to perform or react to restore in this change. Existing soft-deleted source suppression remains; any future supported Event restore operation must reevaluate/enqueue every linked external record whose current source differs from its proposed watermark. That future obligation is documented, not implemented or workflow-tested here.

Use four explicit `private.set_<table>_modified_at()` trigger functions (cities, events, places, media), LANGUAGE plpgsql, SECURITY INVOKER, `SET search_path = ''`. Compare only these columns with null-safe `IS DISTINCT FROM`, joined by OR:

| Table | Semantic columns |
| --- | --- |
| cities | name, description_delta, deleted_at |
| events | name, description, description_delta, start_date, end_date, all_day, latitude, longitude, city_id, category, deleted_at |
| places | name, description, description_delta, latitude, longitude, city_id, category, deleted_at |
| media | url, description, author, license, license_url, width, height, event_id, place_id, deleted_at |

On difference assign `NEW.modified_at := greatest(pg_catalog.clock_timestamp(), OLD.modified_at + interval '1 microsecond')`; otherwise assign `OLD.modified_at`. Return NEW. Exclude id, created_at and modified_at from the predicates. Run on **every** UPDATE with unconditional BEFORE UPDATE triggers retaining the table-local name `handle_modified_at`; neither UPDATE OF nor a trigger WHEN filter can enforce DB ownership on marker-only attempts. A caller-supplied UPDATE marker is ignored in both branches. Do not use row-to-JSON comparison, alter the extension, or alter other tables' trigger functions. Private trigger functions need no public RPC exposure; revoke direct PUBLIC/anon/authenticated/service_role execution grants.

One new migration, in its normal transaction, performs this exact order:

1. Drop only the four old canonical `handle_modified_at` triggers before marker updates.
2. For **every** row on each table where `deleted_at IS NOT NULL`, set `modified_at = greatest(deleted_at, modified_at + interval '1 microsecond')`. This includes already-equal or already-newer markers, not just `deleted_at > modified_at`. Record original values in migration tests and assert each new marker is strictly greater. Do not backfill active rows or guess historical restores. Do not substitute current wall time for deletion chronology.
3. Alter only the four `modified_at` defaults to `pg_catalog.clock_timestamp()`. Keep created_at, constraints, INSERT shape and ability to explicitly supply INSERT markers unchanged; no extra INSERT trigger is needed by audited writers, which omit canonical markers in production inserts.
4. Create the four explicit functions and attach unconditional UPDATE triggers, after backfill so they cannot undo it.
5. Persist the four canonical column comments above, leaving unrelated comments/contracts untouched. Add ordinary non-partial B-tree indexes `<table>_modified_at_idx` on `(modified_at)` and the cursor RPC/ACL described below; notify PostgREST to reload schema following existing migration conventions.

Existing transaction-level migration DDL serialization is enough; do not add application locks or hard-delete guards. The ordinary index matches the lower-bound predicate while existing primary keys support ID ordering; no `(modified_at,id)` cursor/index or premature partial indexes. Full-row equality is rejected because it conflates metadata writes with semantic edits. Never edit historical migrations during apply.

### D2 — Stateless server cursor and inward-facing boundary

Add `public.get_content_sync_cursor() RETURNS timestamptz`, no parameters, LANGUAGE sql, explicitly VOLATILE, SECURITY INVOKER, `SET search_path = ''`, returning `SELECT pg_catalog.clock_timestamp()`. No table access or stored state. Revoke all execution from PUBLIC, anon, authenticated and service_role, then grant EXECUTE only to anon and authenticated (owner retains normal privileges). Test PUBLIC/service_role have no inherited/default EXECUTE grant; do not alter canonical SELECT or write RLS. SECURITY DEFINER is unnecessary.

Add `lib/domain/core/sync_cursor_source.dart` with `abstract interface class SyncCursorSource { Future<Result<DateTime>> getCurrentCursor(); }`, and `lib/data/core/supabase_sync_cursor_source.dart` implementing it using SupabaseClient RPC. Parse the scalar timestamp, normalize `toUtc()`, and return expected RPC/network/format failures as `Result.error`, preserving infrastructure error reporting conventions; do not catch Object to disguise programming failures. Inject this required source into SyncUseCase; construct the Supabase implementation inline beside ObjectBoxSyncTransactionCoordinator in `config/dependencies.dart`, without a separate Provider. No SupabaseClient import belongs in SyncUseCase. Missing RPC is an explicit failed sync, with no silent fallback.

The public RPC changes the generated Supabase schema contract. After applying all migrations in the disposable local stack (`supabase db reset --local`, following the repository's established workflow), regenerate `supabase/functions/_shared/database.types.ts` from stdout of `supabase gen types typescript --local`, using temporary output until diff review succeeds, then format with the repository's Deno conventions. Verify `get_content_sync_cursor` has no parameters and a timestamptz/string result; retain existing generated schemas and existing API types. Review against a pre-change generated baseline if necessary to distinguish unrelated drift; do not hand-edit the generated file or accept unrelated generator/schema drift. Formatting/type-checking and a second generation comparison must confirm reproducibility. This is an apply task; remediation does not run migration/reset/generation or edit the generated file.

U is an observed server high-water **time**, not a commit token or dataset snapshot. Reject both the proposed upper-bound filter and a U==C early exit because neither can account for late visibility across requests.

### D3 — Two timestamps and real previous-store compatibility

Add constructor/default-null, final nullable `DateTime? contentSyncCursorAt` annotated dateNano to AppSettings and its copyWith. Preserve all existing UIDs/IDs, append only the new property through build_runner; never hand-edit generated model or bindings. Null in copyWith can retain the existing value, as for lastSyncedAt; no cursor-clearing API is required.

Expose `contentSyncCursorAt` on SettingsRepository; replace setModifiedAt with `Future<Result<void>> setSyncState({required DateTime lastSyncedAt, required DateTime contentSyncCursorAt})`. One copyWith plus one save persists both; retain `_persistNewSettings` success-only cache publication. Persisting settings separately **after** content commit is intentional: failure is replayable, whereas advancing a cursor before commit could lose data. Existing callers of setModifiedAt are sync and test fakes; update these, not unrelated settings methods.

Before changing model input/generating bindings during apply, capture a **real** closed database produced by this HEAD's unchanged model. Use a temporary producer test and `TestObjectBoxEnvironment`, seed singleton settings with non-default theme/brightness/sort/crashReporting and a known recent lastSyncedAt, plus representative canonical rows and Event/Place saved state. Compress data.mdb into `test/fixtures/objectbox/pre_content_sync_cursor/` with an exact copy of producer model, producer HEAD and hash, and documented row values. Remove the temporary producer after capture; regular tests cannot regenerate the baseline with new bindings. The older pre_all_day fixture demonstrates the pattern but its documented rows do not establish populated settings preservation.

This verifies only old-store → new-model compatibility. It does not establish new-store → exact pre-change binary/model compatibility; once a device opens its cache with the new model, operational rollback must preserve that model, its UIDs and at least contentSyncCursorAt, without requiring a local schema downgrade.

Reopen a copy/decompression using new bindings through the existing harness; assert all settings/cache/saved values and identities preserved, new cursor exactly null, then persist both dates and close/reopen again. Freshly seeding old-looking settings with the new model is not migration evidence. Also retain the pre_all_day reopen gate. Generator command: `dart run build_runner build --delete-conflicting-outputs`; inspect changes to `lib/generated/objectbox-model.json` and `objectbox.g.dart` and discard only unrelated generation changes without overwriting other work.

### D4 — Minimal retrieval API and one keyset helper

Extend `Synchronizable.prepareSync` to `Future<Result<List<T>>> prepareSync({DateTime? modifiedAtOrAfter})`. Extend BaseSyncRepository.fetchRemote with the same optional named argument and forward it from prepareSync. Null means full bootstrap; otherwise the repository uses the supplied lower bound verbatim. Overlap policy stays exclusively in SyncUseCase.

Create one `lib/data/core/fetch_paginated_sync_dtos.dart` helper returning `Future<List<T>>`, with `T extends SyncDto`, SupabaseClient, table name and table-owned `T Function(Map<String,dynamic>)` decoder plus optional lower bound. Each repository passes its existing DTO decoder. The helper accumulates rows; each request builds a fresh `.from(tableName).select()` query, applies `.gte('modified_at', lowerBound.toUtc().toIso8601String())` when present, `.gt('id', lastId)` only after a nonempty page, then `.order('id', ascending: true).limit(500)`. LastId is the final decoded row's numeric id. Stop only at an empty page. No range/offset, deletion filter, timestamp upper bound, compound cursor, streaming local writes or field patches. Full-row select preserves relation-null decoding and existing DTO/mapper ownership.

Page failure or decode failure rejects the entire helper result; BaseSyncRepository's existing Exception handling/logging yields one prepare Result.error with no partial DTO success and no local writes. Four paging loops remain independent asynchronous fetches started together; no serial repository fetching or database transaction around network I/O.

Test support must be pagination-aware: `test/support/mock_supabase.dart` currently returns the same configured payload on **every** request and would loop indefinitely after this change. Extend this shared HTTP stub to return scripted/filter-aware pages ending in an empty page, record request URIs, support cursor scalar RPC and page-specific failure. Preserve convenient existing repository fixture APIs but ensure they honor id filters or explicitly exhaust once; adapt existing tests and central fakes rather than creating four duplicate clients.

### D5 — Uniform freshness merge

After backend legacy repair, remove markEntityDeleted and supportsSoftDelete from base, four overrides and obsolete test-only variants. Keep pendingById, single putMany and current transaction coordinator:

| Local | DTO | Action |
| --- | --- | --- |
| absent | deleted | ignore |
| absent | active | create with mapper |
| present | modifiedAt <= local.modifiedAt | no-op, irrespective of deletedAt |
| present | modifiedAt > local.modifiedAt | full mapper merge including deletion flag and marker |

Fix City toEntity and mergeInto with `isDeleted: deletedAt != null`. Keep local IDs, relation semantics and non-remote fields, especially Event/Place isSaved, through existing copyWith. Do not convert full-row retrieval into patch decoding. Test active updates, deletes, restores, changed already-deleted rows, equal/older tombstones, absent records and duplicate DTOs/replay. Legacy normalization is a prerequisite for switching to this freshness rule: older clients may have seen delete flags without recording newer modification times.

### D6 — Orchestration, scheduling and failure authority

Add a minimal optional `DateTime Function()? now` constructor argument with stored default DateTime.now. Use it for schedule comparison and completion timestamp only. Define `const syncOverlap = Duration(hours: 24)` in SyncUseCase's owning module.

For every actual sync, inside existing Sentry lifecycle:

1. Read local C once from settings.
2. Await cursor source U; on Error return it without preparing or committing anything.
3. Compute lowerBound = C?.toUtc().subtract(syncOverlap); start all four prepare calls with that same lower bound and await record `.wait`.
4. If any prepare fails, return Error without local commit. Otherwise commit all four in the existing ObjectBox write transaction; rollback on any commit failure and return Error.
5. After successful commit, sample `_now()` as completion time and await `setSyncState(lastSyncedAt: completionTime, contentSyncCursorAt: U.toUtc())` once. On Error return sync Error and keep Sentry span failed; retained content is allowed, old persisted/in-memory settings remain authoritative. On success finish span OK and return Success.

Persist U exactly, never device time, greatest observed row marker or latest page time. Do not skip fetches when U==C. Data newer than U can be merged now and will be fetched again later. Replay after settings failure compares markers and does no damage.

`isSyncRequired`: cursor null immediately returns true; otherwise retain existing lastSyncedAt + 3-day inclusive due boundary (or true if lastSyncedAt null), using `_now()`. Forced sync bypasses scheduling through existing ViewModel but still chooses full/delta from C. Do not change fatal classification: failure with previous lastSyncedAt is nonfatal even during cursor-null bootstrap; failure without prior successful sync remains fatal. Keep router/cache/offline behavior and UI surfaces.

### D7 — Overlap correctness envelope

The accepted assumption is: “una transazione che modifica contenuto canonical non rimane non committed per 24 ore dopo l'assegnazione del proprio modified_at.” Current promotion/apply/ingest writers run request-scoped Postgres RPCs; no long-lived production canonical transaction path was found, so this is operationally consistent, not database-enforced proof.

During ID scanning, a passed row can change. Markers after U are above the next lower bound and are retrieved next time; a pre-U transaction becoming visible later within the assumption is caught by the inclusive 24-hour overlap. A short server-capped page still advances by its last id and cannot terminate the scan. This gives at-least-once retrieval with idempotent merge, **not** mathematical commit ordering or a point-in-time multi-table snapshot. No upper bound should pretend otherwise. Hard-delete omissions cannot be discovered by this protocol; canonical removals that must propagate are soft-delete. Manual privileged SQL and historic unobservable restores are outside the guarantee.

## Cursor authority under future projection changes

A stored contentSyncCursorAt is authoritative only for the projection/materialization contract under which it was advanced. The current implementation is complete for the canonical fields used by the current client; cities.description_delta is intentionally semantic in the backend but absent from CityDto/CityEntity. Its omission requires no code change now and does not invalidate the current projection's cursor.

A future release that materializes a previously ignored field, adds a canonical table, or changes mapping semantics to require historical remote state must reconcile every required historical row before treating the existing cursor as authoritative for that new contract. Valid approaches include a complete bootstrap, a targeted backend modified_at backfill/bump, a deterministic local migration when all required inputs are already available locally, or an equivalent strategy with evidence of completeness. A full retrieval alone is insufficient if freshness checks skip the required rematerialization for unchanged/equal markers; the future strategy must actually populate the expanded projection. Waiting for another remote mutation, assuming future deltas will contain old state, or selectively clearing local data without reconciling cursor authority is insufficient. Local-only changes requiring no historical remote input may retain cursor authority.

These are constraints on future changes, not new tasks for this implementation. They introduce no syncSchemaVersion, cursorVersion, Settings property, per-table cursor, migration framework or backend marker. D1–D7 and current runtime behavior remain unchanged.

## Risks / Trade-offs

- [Long uncommitted transactions exceed 24 hours] → Document the assumption against audited request writers; this optimization deliberately does not add ordered replication infrastructure.
- [Bootstrap transfer and memory remain proportional to the entire dataset] → Paging avoids server row caps but DTOs still accumulate before atomic commit, preserving existing two-phase design.
- [Migration backfill changes canonical Event version tokens on deleted rows] → Expected semantic repair; active tokens only change on real mutation thereafter. Run existing Event and external token suites without weakening assertions; do not alter submission/source contracts.
- [Settings write fails after content commit] → Report failure, keep old cursor, retry full/delta as before, prove replay and in-memory cache unchanged.
- [Client released ahead of backend] → Explicit RPC failure and release gate; no incomplete fallback. Installed old clients continue full sync against unchanged row shape.
- [ID-keyset concurrent scans are not snapshots] → Persist pre-fetch U with overlap and never require cross-request snapshot consistency.

## Migration Plan

Apply milestone order in tasks.md. Test a clean backend replay and a genuine pre-migration upgrade with historical tombstones seeded under the old trigger behavior; assert exact max(deletedAt, oldModifiedAt+1us), unchanged created_at/active rows and preserved unrelated marker contracts. DB mutation tests run with explicit fixtures and no sleeps; two immediate updates must be strictly ordered. Future OLD marker fixtures can force the +1us branch deterministically without production clock manipulation.

Backend deployment precedes client release: deploy the new migration, run DB invariant/ACL and promotion/external/concurrency regression gates, verify the RPC through both client roles and unchanged old DTO parsing/full-fetch/deletion behavior, then release delta-aware Flutter. These are apply/release gates, not actions authorized by this planning turn. Pre-upgrade installed full-sync clients remain supported against the migrated backend. After a device has opened ObjectBox with the new model, rollback to the exact pre-change binary/model is not promised safe. Any application rollback must instead be a forward-compatible full-sync hotfix/release retaining the current ObjectBox model, UIDs and at least contentSyncCursorAt; it may bypass delta retrieval but must not require local schema downgrade. This is an operational constraint, not a rollback implementation in this change. The backend migration remains forward-only and must not be revoked; reverting canonical marker semantics while delta clients exist is unsafe. If backend rollout fails, stop client release and fix forward; do not undo tombstone normalization or reset UIDs/cursors.

Concrete database and Flutter gate commands and requirement coverage are recorded in tasks.md. No architectural decision remains open; environment availability and eventual deployment evidence are execution prerequisites, not unresolved design choices.

## Planning remediation verification

Remediation at initial local/remote main HEAD `18ff4ff09427b7675750639d646e32bc68adbf9f` changed only this change's artifacts. The five reviewed findings are addressed by the modified provenance requirement, M1 generated-schema task, D1 persistent column comments and supported-writer creation-metadata invariant, plus actual planning validation.

Executed during remediation: `openspec validate optimize-content-sync-delta-retrieval --strict --no-interactive` (OpenSpec 1.12.0 supports the flag), exit 0, output: `Change 'optimize-content-sync-delta-retrieval' is valid`. This is current planning evidence, separate from the retained future apply gate in Task 4.5. `git diff --check` produced no errors. No runtime test, reset, migration, type generation, apply or deployment was executed by this remediation.
