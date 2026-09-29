## Why

The current database permits invalid event/submission intervals despite application and promotion validation, and annual event visibility requires full containment while day and date-range retrieval use overlap. A cross-year event can consequently disappear from both annual views. Establish the structural and retrieval contract before a separate `allDay` design.

## What Changes

- Add database CHECK constraints that forbid an end without a start and an inverted range on nullable `content_submissions` dates, and forbid an inverted range on `events`, whose start is already `NOT NULL`. The developer reports a completed production audit with zero violations on both tables; no data remediation is planned.
- Make a non-deleted event visible in a Europe/Rome calendar year whenever its interval overlaps that year, including events crossing either year boundary. Apply this consistently to yearly, category, coordinate, and search results, including the search path that traverses city-linked events in memory.
- Keep day/date-range overlap retrieval, start-date-based upcoming events, and inclusive civil-day bounds intact. Document the half-open `[startOfDay, nextDayStart)` query-range conversion as deferred; do not implement it in this change.
- Add focused database and real-ObjectBox regressions and adapt existing promotion tests whose invalid persisted fixtures the new CHECK constraints will reject.

## Capabilities

### New Capabilities

- `event-temporal-integrity`: Defines database date invariants and coherent Europe/Rome overlap visibility for event retrieval. This reuses the capability name from a relevant archived change; no current main spec exists at this path.

### Modified Capabilities

None. The existing `event-temporal-input-validity` spec governs picker and request-input validation rather than database structure or event retrieval; its requirements do not change.

## Impact

- One additive Supabase migration and repository-native local database tests; existing promotion database fixtures need adjustment because invalid submission rows will no longer persist.
- `ObjectBoxConditions.visibleEventInCurrentYear`, its event repository consumers, and both annual-filter paths in `SearchRepositoryImpl`; focused ObjectBox repository tests and relevant contract comments.
- No new dependency, ObjectBox schema or generated-code change, Edge API change, RLS/RPC redesign, `allDay` behavior, upcoming-event semantic change, or half-open range implementation.
