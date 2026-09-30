## Context

See `proposal.md` for motivation and `specs/event-temporal-integrity/spec.md` for the target contract. At `main`, `supabase/migrations/20260822113151_remote_schema.sql` defines nullable `content_submissions.start_date/end_date`, `events.start_date NOT NULL`, and nullable `events.end_date`; the migration history has no chronological CHECK on either table. Shared public/admin Edge date validation rejects end-only and inverted submissions, and the promotion RPC checks event readiness, but these paths do not enforce the structural invariant for every database writer. An archived event-time design described corrected backend constraints as authoritative; the current migration definitions do not contain them, so the present schema is the implementation baseline.

The developer supplied a completed, independent production audit immediately before this proposal: zero `content_submissions` rows with end-without-start or end-before-start and zero `events` rows with malformed/null start or end-before-start. This is an external audit result, not a query run by this planning task. It is the prerequisite for direct validated CHECK introduction; there is no data-repair migration. A lightweight repeat immediately before deployment may detect intervening writes but does not replace or retroactively change the completed audit.

`ObjectBoxConditions.visibleEventInCurrentYear` currently requires a ranged event to be wholly contained in the current Europe/Rome year. `EventRepositoryImpl.getByCurrentYear`, `getByCategories`, and `getByCoordinates` call that condition. `SearchRepositoryImpl.getEventIdsByQuery` also calls it for name/category matches and separately mirrors containment in an in-memory city-event traversal. Thus a 31 December–1 January ranged event can disappear from both annual years. In contrast, `getByDate`/`getByDateRange` already use overlap; `getNextEventIds` selects starts inside a rolling 30-day window and naturally crosses New Year. All these query bounds come from `EventTimePolicy` and `EventCalendarDate` using Europe/Rome, not device local time.

## Goals / Non-Goals

**Goals:**

- Make database temporal validity structural for both tables while respecting their different nullability.
- Change every current-year visibility path to the same overlap rule in one application implementation, preserving soft-delete, category, coordinate, and search filters.
- Prove the rule with real temporary ObjectBox stores and the database checks with the repository's local PostgreSQL test style.

**Non-Goals:**

- No `allDay` field or behavior; this change establishes its future prerequisite only.
- No change to day/date-range query behavior, upcoming-event start-window semantics, or future `Eventi in corso` behavior for already-started active events.
- No half-open civil-day conversion, new time package, ObjectBox model/generator change, data rewrite, trigger, function, RPC redesign, Edge response change, or unrelated cleanup.

## Decisions

### 1. Add three direct, named database CHECK constraints

Add a forward-only timestamped migration using the repository's `ALTER TABLE public.<table> ADD CONSTRAINT ... CHECK (...)` style and descriptive snake-case names. `content_submissions` gets one check equivalent to `end_date IS NULL OR start_date IS NOT NULL` and one equivalent to `end_date IS NULL OR end_date >= start_date`. The first is necessary: PostgreSQL CHECK accepts a null truth value, so the chronology expression alone would not reject end-without-start. `events` gets only `end_date IS NULL OR end_date >= start_date`; its existing `start_date NOT NULL` already rejects a missing start. Direct validated constraints match the completed zero-violation audit. Existing Edge and promotion validation remain defense in depth.

Alternative: use a trigger or duplicate the end/start-presence check on `events`. A trigger is unnecessary for row-local comparisons, and the duplicate check adds no invariant.

The new constraints make three existing promotion database fixtures invalid at setup: the end-only place-promotion case and the ordinary and sub-millisecond inverted event-promotion cases in `supabase/tests/submission_promotion_db_test.ts`. Adapt these tests to assert rejection at the new database boundary, retain valid promotion and missing-start RPC coverage, and leave the RPC's defensive inverted-range branch in place. Do not disable constraints or manufacture impossible persisted rows solely to call that branch. Cover insert and update, including microsecond ordering, in repository-native local PostgreSQL tests; test submissions and events independently.

### 2. Change shared annual ObjectBox membership, and update search's in-memory mirror

Keep `visibleEventInCurrentYear` as the shared ObjectBox condition. For non-null ends use `startDate <= endOfYear AND endDate >= startOfYear`; for null ends keep start-within-year matching. Continue applying `isDeleted == false`. Derive both inclusive year endpoints from `EventTimePolicy.utcRangeForCalendarDate` so a fixed UTC clock resolves the Europe/Rome year, including its UTC rollover. Update the helper's documentation and the repository interface comment that describes the annual result.

Because search also traverses `city.events` in memory, update `_isVisibleEventInCurrentYear` to the same comparison and its comment in the same application change. The ObjectBox condition continues serving name/category search queries. The in-memory predicate is a necessary representation-specific mirror; focused parity tests are preferable to a new cross-layer query abstraction for this single use.

Alternative: change only `getByCurrentYear` or duplicate overlap conditions in each caller. Both leave actual annual consumers inconsistent; direct caller-specific predicates would also bypass the shared visibility rule.

### 3. Preserve distinct day, upcoming, and persisted-end contracts

`EventRepositoryImpl._getByDateRange` already tests interval overlap with separate null-end handling. Only remove or correct its comment that explicitly contrasts day overlap with annual containment. Do not refactor its predicate or alter `getByDate`/`getByDateRange` results. `getNextEventIds` remains based on event starts in the inclusive 30-day Rome window; an event started yesterday and still active is not a “prossimo evento”. A future `Eventi in corso` section owns that different question. Preserve existing New Year and window-boundary regressions.

`EventUtcRange` currently represents a Rome day as `[startOfDay, 23:59:59.999999]` in UTC. Its `endUtc` is used both by queries and by event editing/repair as a proposed or persisted event end instant. The existing representation is coherent and tested, with no demonstrated defect requiring a change here. **Conversion to half-open query ranges `[startOfDay, nextDayStart)` is explicitly deferred until a concrete requirement or demonstrated defect justifies it.** Mechanically replacing `endUtc` with `nextDayStart` would conflate an exclusive query boundary with an inclusive event end instant and broaden this hardening. If a future change is justified, first consider separating query-bound concepts such as start-inclusive/end-exclusive from explicit persisted/editing end instants; this is design guidance, not a prescribed API.

A future half-open proposal must independently specify and test Europe/Rome behavior for a normal civil day, spring DST transition, autumn DST transition, multi-day and cross-year events, exact midnight boundaries, an event ending exactly when the next civil day starts, and the distinction between exclusive query bounds and persisted end instants. None of this deferred conversion is an implementation task in this change.

### 4. Exercise all observable annual paths with deterministic clocks

Extend `test/data/repositories/event_repository_impl_test.dart` using its real temporary ObjectBox store and injected `nowUtc`. Cover null-end in-year, in-year ranged, wholly before/after, crossing in from the prior year, crossing out to the next year, spanning the entire year, exact inclusive first/last instants, and soft deletion. A representative cross-year entity must be included by `getByCurrentYear`, `getByCategories`, and `getByCoordinates` under matching filters; use a non-identical nearby coordinate because the coordinate query excludes the input point itself. Test the same event with clocks in both Rome years. Adapt tests whose names currently say containment, and retain day/date-range overlap and upcoming New Year assertions.

Extend `test/data/repositories/search_repository_impl_test.dart` so the same cross-year membership holds for direct name, category-label, and linked-city paths, including the in-memory city's temporal filter and soft-delete exclusion. This covers the discovered consumer beyond the three event repository methods. Do not rely on an isolated helper test as the only proof.

## Risks / Trade-offs

- [A write occurs after the zero-violation audit but before migration] → Optionally repeat the two small violation queries immediately before deployment; stop deployment and investigate if either is nonzero rather than silently adding repair scope.
- [A CHECK breaks existing promotion fixtures] → Update those tests to assert the new rejection boundary, retain valid/missing-start promotion coverage, and keep the RPC guard without bypassing constraints.
- [Search city results diverge from ObjectBox search or listing] → Change its mirrored predicate in the same implementation and prove parity with cross-year integration cases.
- [A boundary fixture uses the device zone or wrong UTC rollover] → Derive boundaries with the existing Europe/Rome policy and inject fixed UTC clocks; assert exact first/last inclusive instants.
- [A later developer mistakes `endUtc` for a query-only endpoint] → Keep the half-open deferral and persisted-end distinction explicit in this design.

## Migration Plan

1. During implementation, reconfirm the schema and affected consumers against `main`; preserve unrelated work. The completed production audit is already documented above. A short pre-deploy repeat is optional defense in depth, not an additional data-remediation phase.
2. Add the three named CHECK constraints in one additive migration and local PostgreSQL regression coverage. Adapt promotion fixtures that can no longer represent valid stored rows. Verify no RLS, RPC, or generated-type contract change is needed.
3. Apply the annual overlap change atomically across the shared ObjectBox condition and search's in-memory mirror, then update documentation and focused repository regressions. Keep day/date-range and upcoming production predicates unchanged.
4. Run the local database tests and repository-native runners, focused ObjectBox repository tests, full relevant Flutter/Deno tests, `flutter analyze`, formatting/type checks for touched files, and strict OpenSpec validation. Review the diff for no `allDay`, half-open, or unrelated changes.
5. Deploy the additive database migration after confirming the target data still satisfies the audit predicates, then release the application semantic change as one unit across all annual consumers. If a rollback is necessary, revert the application release independently; dropping validated CHECKs would require a separately reviewed migration and reason, not an implicit data repair.
