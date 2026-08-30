## Why

The staged event-time implementation can still crash an administrator who opens an end-date picker for a hydrated inverted range, and its shared Edge Function validator can accept impossible Gregorian dates because JavaScript normalizes them. This focused follow-up hardens those two invalid-input boundaries without treating malformed historical data as supported legacy state.

## What Changes

- Make shared date-picker presentation bounds valid for Material and compact iOS/Cupertino date pickers even when a hydrated selected end day precedes its lower bound, including a cross-year inversion that would otherwise put both the initial and upper dates before the lower date.
- Clamp picker-only presentation values without mutating, persisting, or making the malformed event draft valid merely because the picker was opened; a confirmed valid replacement remains the supported repair interaction.
- Make the existing shared public/admin submission-date request validator recognize the project's intended ISO-like lexical contract—date-only plus offset-less, `Z`, numeric-offset, and supported fractional-second date-times—and apply strict Gregorian calendar validation to every accepted form rather than preserving arbitrary V8 `Date.parse` compatibility.
- Preserve existing client persistence validation, backend range ordering (including microseconds), adapter-specific validation messages, and original validated strings.
- Add focused picker, shared-validator, and public/admin request-adapter regressions.
- Explicitly exclude legacy ObjectBox compatibility, historical-state projections or migrations, database schema/data changes, and unrelated event-time behavior.

## Capabilities

### New Capabilities

- `event-temporal-input-validity`: Defensive picker presentation for malformed event ranges and strict Gregorian validity at shared public/admin request boundaries.

### Modified Capabilities

None.

## Impact

- Flutter shared event-date picker behavior and focused widget/editor tests under `lib/ui/content_submission/widgets/` and `test/ui/`.
- Shared Deno date validation plus public/admin submission adapter tests under `supabase/functions/`.
- No package change, ObjectBox schema/generation change, Supabase migration, persisted-row rewrite, database-constraint change, or legacy compatibility layer is expected.
