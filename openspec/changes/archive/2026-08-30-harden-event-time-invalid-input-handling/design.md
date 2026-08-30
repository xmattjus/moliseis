## Context

See `proposal.md` for motivation and `specs/event-temporal-input-validity/spec.md` for required behavior. The implementation baseline is the current staged event-time patch, not only `HEAD`; unrelated unstaged and untracked work must be preserved.

`ContentSubmissionFields` supplies the shared end-date chip with `firstDate = startCalendarDate` and `selectedDate = endCalendarDate ?? startCalendarDate`. `ContentSubmissionDateChip` currently derives `lastDate` from the unadjusted selected year and passes those carriers directly to Material `showDatePicker` or compact-iOS `CupertinoDatePicker`. Flutter 3.41.9 requires the initial date to lie within the lower and upper dates for both picker implementations, and Material additionally requires the upper date not to precede the lower date. An inverted hydrated range can violate both conditions before a callback is possible.

Both public and admin ViewModels already route confirmed end-date edits through `EventTimePolicy.changeEndCalendarDate`, while `EventTimePolicy.validateForPersistence` rejects an end instant before its start. Admin detail hydration and local draft mapping can currently construct an exact draft without enforcing range order. This follow-up does not expand which historical ObjectBox shapes are supported. The statement in `repair-event-time-review-findings/design.md` that no inverted persisted range need be openable is obsolete only at the picker-presentation boundary; that change's rejection of legacy domain states, inference, fallback parsing, and migration remains intentional.

The public and admin Edge Function adapters already delegate to `supabase/functions/_shared/submission_dates.ts`. It currently accepts non-empty strings for which `Date.parse` is finite, preserves the original strings, rejects end-only/inverted pairs, and retains fractional digits beyond milliseconds for ordering. JavaScript can normalize impossible calendar components and accepts implementation-defined alternate spellings, so runtime parseability alone is insufficient to define syntax or Gregorian validity at this untrusted request boundary. The intended project contract is the existing ISO-like date-only and date-time families already pinned by tests. No database write, schema, promotion RPC, or migration participates in this validation defect.

This focused change requires zero-clean targeted analysis for its touched/authored Dart source and tests. It does not require a repository-wide analyzer baseline comparison and must not expand into unrelated lint cleanup.

## Goals / Non-Goals

**Goals:**

- Establish one picker-presentation calculation that always supplies valid date-mode lower, initial, and upper carriers on both supported platform paths.
- Keep picker presentation strictly non-authoritative: only a confirmed picker callback may change a draft, and normal persistence validation remains the readiness gate.
- Add Gregorian component validation inside the existing shared backend helper before public/admin adapters accept request dates.
- Preserve the intended ISO-like syntax families, original-string output, adapter-specific errors, and microsecond-aware instant ordering.

**Non-Goals:**

- Validate or normalize event state during hydration, silently repair data when a picker opens, or add a second client date policy.
- Restore pre-schema ObjectBox rows, infer event mode from `isEvent == null`, represent an end-only legacy draft, add compatibility projections/parsers, or migrate local data.
- Change event-time ordering semantics, inclusive Rome end-of-day policy, DST handling, public/admin request envelopes, database constraints, persisted rows, promotion SQL, dependencies, or generated ObjectBox output.

## Decisions

### 1. Normalize only the date picker's presentation triple

At the shared `ContentSubmissionDateChip` date-mode boundary, derive a presentation-only triple from the semantic values:

1. Keep the requested lower bound (`firstDate`, or the existing selected-year January 1 default).
2. Clamp only the picker initial date upward to that lower bound when the selected date precedes it.
3. Derive the upper bound as December 31 of the effective initial date's year.

For a valid input, the effective initial equals the selected date and all three values remain exactly as today. For an inverted input, using the clamped initial's year also prevents `lastDate < firstDate` when start and end are in different years. The required regression uses a December 2026 selected end and a January 2027 lower bound, and proves `initialDate >= firstDate` plus `lastDate >= firstDate` on Material and their `initialDateTime`/`minimumDate`/`maximumDate` equivalents on compact iOS. Keep these values private picker carriers; do not write them back to widget properties, callbacks, ViewModels, `EventDateDraft`, or persistence. Apply the same calculated carriers to Material and compact iOS paths rather than adding platform-specific fixes. Time-mode behavior and its five-minute default remain unchanged.

Alternative considered: clamp or replace `endCalendarDate` in `ContentSubmissionFields` or a ViewModel before opening. Rejected because rebuilding the controlled state would disguise invalid data, risk persistence through existing debounce/save paths, and conflate crash hardening with normalization.

Alternative considered: drop the lower bound when the selected end is invalid. Rejected because it would allow another invalid end selection and weaken the supported repair interaction.

### 2. Keep mutation behind existing confirmation callbacks and validation

Material already emits only after the dialog returns a selected value. Cupertino seeds its internal modal selection from the presentation initial and emits only when the user presses `Conferma`; cancel/dismiss must not invoke the callback. Retain that lifecycle. Confirming the clamped initial is a supported explicit replacement action, but opening or cancelling is not.

Add direct shared-chip tests for both platform picker configurations and callback behavior using the required cross-year inversion, plus an admin editor regression using the existing fake repository and screen harness: hydrate that inverted current submission, open and cancel the end picker, and prove exact start/end values, clean/dirty state, and repository writes are unchanged while persistence validation still reports `invalidRange`. Reuse existing test setup; do not add a production seam or duplicate test support. A normal confirmed valid end selection remains covered through the existing semantic callback/ViewModel tests and should be strengthened only if the new scenario exposes a gap.

Alternative considered: test only a pure bounds helper. Rejected because it would not prove Flutter's actual Material and Cupertino constructors receive valid values or that opening the controlled editor is non-mutating.

### 3. Define syntax before Gregorian and instant validation

Make `submission_dates.ts` recognize the intended ISO-like lexical contract before invoking runtime instant parsing: exact `YYYY-MM-DD`, plus the existing `YYYY-MM-DD` date-time family with no offset, UTC `Z`, or an explicit numeric offset and optional fractional seconds at the precision already supported by the backend. The implementation may use a focused parser or regular expression, but every accepted branch must expose the same year/month/day components for validation. Reject strings outside those forms even if V8 `Date.parse` happens to accept them.

After syntax recognition, validate the stated year/month/day by exact component round-trip or equivalent Gregorian leap-year/month-length logic. The required matrix proves the century rule and month lengths: `2000-02-29`, `2024-02-29`, and `2024-04-30` are valid; `1900-02-29`, `2023-02-29`, and `2024-04-31` are invalid. Apply the same calendar check to offset-less, `Z`, explicit-offset, and fractional-second date-times. Only after syntax and Gregorian validity succeed may existing runtime parsing establish instant validity and ordering keys.

Do not replace the contract with a `Z`-only or fixed-three-digit timestamp grammar. All listed ISO-like forms continue unchanged, including positive/negative numeric offsets and existing microsecond precision. The helper continues to return `invalid_start_date`/`invalid_end_date`; adapters retain their current messages and successful values retain the original string.

Alternative considered: compare `new Date(value).toISOString()` with the input. Rejected because offsets, offset-less values, date-only values, and fractional precision legitimately produce different strings.

Alternative considered: keep accepting every finite `Date.parse` result and inspect Gregorian components only when a canonical prefix happens to match. Rejected because that leaves runtime-specific alternate syntax outside the calendar guarantee and lets V8 define the public request contract.

Alternative considered: rely on PostgreSQL casts or constraints. Rejected because public/admin request adapters are the existing untrusted-input boundary, and malformed requests must be rejected before persistence without requiring a migration or data rewrite.

### 4. Keep Gregorian validity separate from instant ordering

Do not modify `instantKey` or `isBeforeInstant` except for a strictly necessary refactor that preserves behavior. First establish that each non-null field is lexically supported, Gregorian-valid, and a valid instant; only then enforce end-requires-start and microsecond-aware ordering. Tests must independently cover impossible calendars and ordering so a calendar rejection cannot mask a precision regression.

## Risks / Trade-offs

- [A bounds calculation fixes one platform but still violates another constructor invariant] → Assert the concrete initial/minimum/maximum or initial/first/last values from real Material and Cupertino picker widgets in focused tests.
- [Presentation clamping leaks into controlled state] → Keep the calculated values local to picker opening and verify cancel/dismiss leaves exact hydrated instants, dirty state, validation result, and captured repository inputs unchanged.
- [Lexical validation accidentally removes an intended ISO-like form] → Pin date-only, offset-less, `Z`, positive/negative numeric-offset, fractional-second, and original-string cases through the shared helper and both adapters; do not preserve uncontracted runtime-specific spellings.
- [Calendar tests pass while sub-millisecond ordering regresses] → Retain equal-offset and within-one-millisecond ordering cases alongside new calendar cases.
- [The task expands into unsupported legacy repair or database work] → Stop if implementation appears to require an ObjectBox compatibility state, migration, row rewrite, SQL constraint, or promotion change; report that contradiction instead of expanding this change.
- [Unrelated staged or unstaged work is overwritten] → Inspect cached and working-tree diffs before and after implementation, touching only the planned authored files and tests.

## Migration Plan

1. Add shared picker-presentation normalization and its focused Material/Cupertino regressions without changing editor state ownership.
2. Add shared Gregorian component validation and extend shared/public/admin request-validation matrices while leaving ordering code and adapter messages intact.
3. Run targeted Flutter analysis for touched/authored Dart, targeted Deno checks, and the broader shared-boundary regression set. Do not require repository-wide analyzer comparison. Confirm no generated, dependency, ObjectBox, migration, SQL, or unrelated files drift.

Deployment is source-only with the existing Flutter and Edge Function release paths. No schema or data migration is required. Rollback reverts the focused picker and shared-validator changes; no data rollback is needed because neither opening a picker nor rejecting a request writes or rewrites data.
