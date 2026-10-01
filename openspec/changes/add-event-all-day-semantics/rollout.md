# Deployment and rollback handoff

No deployment was performed. Remote execution requires a separate request.

## Release order

1. Apply database migration `20261001175539_add_event_all_day_semantics.sql`.
   Keep the additive columns/defaults and existing temporal constraints. The
   replaced RPC has one identity and optional trailing `p_all_day`; refresh its
   PostgREST schema cache as the migration specifies.
2. Release compatible public/backend/Admin code. Coordinate the Admin backend
   and editor because its full-input envelope gains three required keys. Public
   legacy payloads may omit the mode and remain timed.
3. Release Flutter models, generated cache schema, draft policy, editors and
   rendering. No forced update, version routing or adoption-percentage gate.
4. Release the importer. EventiMolise remains timed; future live providers are
   separate changes.

Local gate evidence is recorded in `verification.md`:

- Actual PostgREST dispatch supports omitted/default-false and explicit-true
  arguments; service-role execution succeeds and public roles remain denied.
- The unchanged preceding DTO/mapper at execution HEAD tolerated an extra
  remote `all_day` key. This is representative decoder evidence, not published
  application startup or full-sync certification. Older clients may show the
  technical midnight for date-only events.
- The evolved ObjectBox model reopened a genuine preceding cache, preserving
  historical false, dates, draft identity and saved state. Existing UIDs were
  preserved; new-mode writes and unresolved timed recovery passed.

## Rollback

Stop producing new date-only events before reverting writers or UI. Retain both
additive columns, defaults, minimal constraint and all already stored mode/date
information. Do not reclassify all-day rows, rewrite their timestamps, infer a
clock or perform a heuristic backfill.

Keep the compatible RPC/backend boundary while reverting callers; its optional
argument accepts the prior public argument set. Coordinate any Admin rollback
with its corresponding full-input contract. A preceding Flutter decoder may
display midnight; the focused gate establishes only technical row decoding.

Do not drop schema/data as an automatic rollback. Any destructive schema
rollback requires a separate migration and review.
