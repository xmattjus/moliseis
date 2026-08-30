## Context

See `proposal.md` for motivation and `specs/event-temporal-integrity/spec.md` for required behavior. The implementation under review is a 50-file staged patch based on `9027a7b1f5d8c22a24736b1506c538c5e3471f98`, not a post-baseline commit. The checkout also contains unrelated unstaged and untracked work that must be preserved.

The temporal architecture remains the foundation: `EventCalendarDate` and `EventClockTime` represent civil values, `EventTimePolicy` is the only production owner of IANA `Europe/Rome` conversion, persistence/wire instants are UTC, repositories own ObjectBox query boundaries, and public/admin editors share policy semantics without sharing their lifecycle logic. PostgreSQL promotion rechecks event readiness transactionally.

The corrected backend constraints and stored data are authoritative. Persisted events therefore have a valid start instant, an optional end instant, and no end before the start. Flutter must target only that canonical contract. Historical end-only, inverted, malformed, or otherwise incompatible persisted dates are not supported input and must not acquire a compatibility parser, fallback, coercion, normalization, repair, or migration path in this change.

The current analyzer baseline is non-zero: the review observed 20 informational diagnostics, none in staged implementation paths. Verification therefore distinguishes zero-clean targeted authored paths from repository-wide baseline comparison. Generated ObjectBox Dart is generator-owned and must not be hand-edited.

The repository ignores `pubspec.lock`, so a clean checkout has no canonical complete dependency resolution. A fresh `flutter pub get` may select newer unrelated and transitive packages than the primary worktree. The observed clean-worktree failure in `test/data/repositories/admin_content_submission_repository_impl_test.dart` under such a resolution is dependency-upgrade compatibility evidence outside this event-time repair; it must not be repaired, waived as an event-time regression, or pulled into this change. Tracking an application lockfile or another canonical dependency-resolution mechanism is a separate repository reproducibility follow-up.

## Goals / Non-Goals

**Goals:**

- Repair each still-applicable merge-blocking temporal defect without replacing the established civil-time architecture.
- Make asynchronous selected-day state deterministic under initial load, retry, and reload ordering.
- Preserve canonical optional-end semantics and current transient editor states without supporting invalid persisted history.
- Remove migration-only ambiguous editor APIs and legacy-only date representations while all visible callers are still in the staged patch.
- Produce objective clean-resolution, focused regression, full-suite, and local-database proof.

**Non-Goals:**

- Redesign the public/admin ViewModels, Provider/Command/Result architecture, ObjectBox schema, event current-year semantics, or promotion transaction.
- Add or alter a database migration, Edge Function date parser, RLS/authorization rule, rate-limit ordering, or accepted timestamp syntax.
- Preserve, repair, normalize, coerce, or migrate persisted `start_date`/`end_date` values outside the current backend contract.
- Remove defensive behavior that serves valid optional values or current incomplete editor interactions rather than malformed historical data.
- Edit generator-owned ObjectBox output unless an intentional generator input unexpectedly requires regeneration; if it does, stop and reassess scope.

## Decisions

### 1. Make only the dependency hunk part of the implementation patch

Keep `timezone: ^0.11.1` as a direct runtime dependency because `EventTimePolicy` imports its data and timezone APIs and Dart itself does not provide IANA history. Selectively include that `pubspec.yaml` hunk in the staged implementation while leaving the pre-existing `version: 2.5.0+105` worktree hunk untouched. The ignored lockfile means the manifest proves the declaration is present and resolvable, but not a canonical complete clean-checkout dependency graph; dependency-upgrade compatibility is outside this change.

Alternative considered: remove the package or hand-code Rome transitions. Rejected because it would weaken the already-correct DST design and spread timezone mechanics.

### 2. Give nullable event ends three-state copy semantics

Change only `EventEntity.copyWith.endDate` to follow the existing `_unset` sentinel pattern used by nullable fields in the same entity: omission preserves the old value, explicit `null` clears it, and a `DateTime` replaces it. `EventDto.mergeInto` can continue passing the authoritative nullable end after UTC conversion. Add entity-copy and DTO-merge regressions so a canonical ranged event can synchronize to a canonical start-only event without collapsing omission and clearing.

This is current optional-field behavior, not legacy compatibility.

Alternative considered: clear the end in the repository after merge. Rejected because it would duplicate nullable update semantics outside the entity and leave other callers incorrect.

### 3. Enforce one canonical persisted-date boundary in Flutter

Remove legacy-only representations and hydration paths whose sole purpose is to preserve malformed historical data, including the end-only `EventDateDraft` state and its mapper/test projections. A persisted event without its required start must produce an explicit data-contract failure rather than being coerced to the Unix epoch. Do not replace removed legacy paths with silent discard, picker clamping, fallback parsing, normalization, or another repair representation.

Retain `EventDateDraft` states needed by current editing: event mode may be disabled, a start calendar date may temporarily await a clock selection, and a canonical event may have no end. Retain the established `_withEndRepair` behavior when a current user edit moves a previously valid start past its valid end; that is deterministic editing policy for canonical input, not hydration support for an inverted persisted range. Persistence validation continues to block drafts without an exact start or with a nonchronological end.

Material and compact-iOS pickers receive bounds derived only from canonical persisted/current editor state. No implementation or test must make an inverted persisted range openable. Picker callbacks remain non-null because clearing event fields is an explicit event-mode action rather than a picker result.

Alternative considered: retain legacy constructors and clamp invalid loaded values at presentation boundaries. Rejected because it keeps unsupported historical data representable and disguises backend-contract violations as editable current state.

### 4. Tie selected-day cache validity to the current yearly-event revision

On each successful yearly load, replace `_all`, advance a small in-memory revision, and recompute the selected-day projection from the new `_all`. If that projection is empty, invalidate the same-day cache marker so a genuine subsequent cache miss can still use `getByDate`.

A date fallback captures both the selected date and yearly revision before awaiting the repository. Its result updates `_byDate` only if the date is still selected and the yearly revision has not advanced; otherwise the latest yearly projection wins. A failed yearly load does not invalidate otherwise valid data. This resolves both completion orders without moving repository orchestration into the widget.

Extend `test/support/fake_repositories.dart` additively with the smallest configurable pending yearly/date result needed to drive completion order; do not create a second local repository fake.

Alternative considered: merely clear `_loadedDate` in `_loadAll`. Rejected because an already in-flight older date result could still overwrite newer yearly state.

### 5. Prevalidate the requested event promotion target in the ViewModel

Keep the loaded editor state and the requested promotion target distinct. `_promote` first runs the existing moderation guard against the loaded submission. Only after that guard succeeds, when the requested target is `AdminPromotionTarget.event`, derive an event-enabled validation projection with `_eventTimePolicy.enable(_eventDates)` and apply the existing persistence-validation path used by save to that projection; do not duplicate or reimplement the temporal readiness rules inside `_promote`. Do not assign the projection back to `_eventDates`, mark the editor dirty, or otherwise change editor dirty-state semantics.

For a normally loaded clean submission with no event dates, the persisted temporal state therefore remains disabled and the moderation guard passes. The event-target validation projection is enabled but empty, so validation publishes `EventTimeIssue.missingStartDate`, the command returns a local `Result.error`, and the repository is not called. Existing valid event promotion and place-target behavior remain unchanged. Backend RPC checks remain unchanged and authoritative.

Test this ordering from a normally loaded, clean submission with no event dates, then request `AdminPromotionTarget.event`. Do not construct a clean incomplete-event editor state, manipulate private state, hydrate malformed persisted dates, invoke legacy compatibility behavior, or save an invalid event draft solely to create the scenario.

Alternative considered: validate only in the confirmation widget. Rejected because direct command callers would bypass it.

### 6. Finish the semantic editor API migration now

Remove the six production-unused `setStartDate`/`setStartTime`/`setEndDate` nullable-`DateTime` adapters from the public and admin ViewModels and remove `ContentSubmissionDraft.startDate/endDate` compatibility projections. Remove legacy-only event-date symbols and callers identified by repository-wide search. Migrate affected tests to `setStartCalendarDate`, `setStartClockTime`, `setEndCalendarDate`, and `eventDates`, but do not recreate malformed historical scenarios through those APIs.

Make picker/field callback values non-nullable because both platform pickers emit a value only on confirmation and event clearing is an explicit checkbox action. The union widget may still store nullable callback fields internally to distinguish date and time constructor modes; emitted values and controlled field contracts are non-null. Keep UTC `DateTime` only at exact-instant, persistence, DTO, and valid picker-carrier boundaries.

Alternative considered: retain adapters or legacy date states for hypothetical callers. Rejected because repository-wide search found no production need and those surfaces reintroduce ambiguous zones or unsupported persisted states.

### 7. Make current-year tests derive fixtures from an injected UTC clock

For every event/search repository test whose expectation depends on “current year”, “today”, or an upcoming window, define a fixed UTC instant, inject it through the existing `nowUtc` seam, and derive fixture instants from the same Rome-aware scenario. Keep deliberately non-UTC values only where the test explicitly verifies input normalization. Continue using the real temporary ObjectBox store and existing support fixtures.

### 8. Remove the calendar's test-only production seam while its suite is in scope

Remove `EventsCalendar.calendarBuilder` and the `EventsCalendarBuilder` typedef; production always selects `_buildCalendar`, so this indirection exists only for one test. Keep `calendarDateBounds` as the narrow deterministic unit boundary and test its Rome-derived carriers for canonical data, while retaining one focused real-widget wiring case only if it adds behavior beyond that pure function.

Move complete `isEventOnDay` scenario ownership to `test/ui/event/view_models/event_view_model_test.dart`. Remove repeated first-day, last-day, and out-of-range cases from `events_calendar_test.dart`, whose remaining responsibilities are canonical calendar carriers, marker/rendering wiring, selection, and the cache interactions changed by this plan.

Alternative considered: keep the seam for hypothetical renderer replacement. Rejected because there is no product substitution requirement and the already-touched tests can prove the stable boundary without exposing third-party builder types in the widget API.

## Risks / Trade-offs

- [An execution environment does not actually provide the authoritative backend constraints or corrected data] → Stop and report the missing precondition; do not add compatibility code, fallback parsing, or a migration to this change.
- [Removing a legacy-only path also removes behavior needed by valid nullable or current incomplete states] → Classify each caller before deletion and retain disabled, unresolved-start, and optional-end scenarios built through supported current APIs.
- [A hidden caller still depends on a removed compatibility symbol] → Run repository-wide symbol searches before deletion and stop if a production or external package consumer demonstrates a current canonical use.
- [Cache revision logic accidentally suppresses a legitimate fallback] → Invalidate an empty yearly projection for future requests, and test both completion orders, same-day retry, addition, replacement, and removal.
- [Shared fake changes alter unrelated tests] → Make pending-result support additive with unchanged defaults and run every materially affected fake consumer plus the full Flutter suite.
- [Test simplification removes distinct coverage] → Compare both suites before deletion; retain each unique Rome rollover or widget-wiring assertion and remove only scenarios that call the same ViewModel implementation with the same expectations.
- [Unrelated dirty work is staged or overwritten] → Inspect worktree and cached diffs before/after each unit; selectively stage only the timezone dependency hunk and never stage the version hunk or unrelated files.
- [A fresh clean checkout resolves newer unrelated/transitive packages] → Do not copy an ignored local lockfile or treat that resolution as canonical. Preserve the primary-worktree focused and full Flutter gates for this change, record the absence of a tracked canonical resolution as a reproducibility follow-up, and do not repair unrelated failures exposed only by the upgrade.

## Migration Plan

1. Confirm the authoritative backend/data precondition, then repair nullable-end synchronization and replace legacy-only Flutter date paths with canonical mapping and explicit contract failure.
2. Complete semantic editor API cleanup, requested-target promotion prevalidation, and selected-day cache ordering without adding malformed-data accommodations.
3. Stabilize repository clocks and simplify the already-touched calendar tests while preserving distinct canonical coverage.
4. Run focused checks, full Flutter checks in the established primary worktree, the local promotion database suite, repository-wide legacy-symbol searches, and strict OpenSpec validation.
5. Reconstruct the exact staged patch in an otherwise clean temporary checkout/worktree and compare its diff to the cached patch. Verify that the manifest contains only the `timezone` declaration change and no version hunk, and run fresh `flutter pub get` only to prove that declaration resolves without copied lock or package state. Do not use the resulting ignored lockfile as repository-canonical state or require repository-wide tests under newly resolved unrelated/transitive versions. Handoff is blocked if the authoritative backend/data precondition is unavailable, compatibility behavior is reintroduced, the staged dependency is absent, the unrelated version hunk enters the patch, or any mandatory scoped proof is not PASS. The absence of a tracked canonical dependency resolution remains a separate follow-up.

Rollback before merge is source-only: revert these focused repairs while preserving unrelated worktree changes. No data/schema rollback is needed because this change adds no migration and does not alter ObjectBox model IDs.
