## Why

Events whose date is known but whose meaningful start time is unavailable cannot currently travel through the submission, moderation, import, synchronization, and display pipeline without inventing a time. Introduce one explicit temporal mode now so future date-only providers can use the existing architecture without another database, domain, or UI contract change.

## What Changes

- Define `allDay` as “known event date, no meaningful start time available”, never as a claim that the event lasts all day. A real midnight remains timed.
- Add `all_day boolean NOT NULL DEFAULT false` to submissions and events, preserving temporal CHECKs and historical timed semantics without classification/backfill.
- Accept mutually exclusive civil-date and existing timed inputs; normalize date-only events to inclusive Europe/Rome bounds through shared backend validation. Extend atomic submission persistence, first-commit-wins replay, promotion, and the existing full-input Admin boundary.
- Propagate the flag through Flutter domain, wire mapping, DTOs, ObjectBox, synchronization, immutable drafts, and editor transitions; add “Senza orario” and suppress synthetic times in event displays.
- Extend the existing importer contract and test date-only adapters while keeping EventiMolise timed and its deduplication unchanged. New provider integrations remain separate changes.
- Preserve inclusive ranges, date-based retrieval, upcoming-event semantics, sorting, and technical compatibility with released clients. Residual RPC, decoder, query-consumer, and generated-model checks are implementation gates, not open architectural decisions.

## Capabilities

### New Capabilities

- `event-all-day-semantics`: Normative meaning, Rome normalization, persistence and propagation, draft mode transitions, Admin editing, importer behavior, rendering, and technical legacy compatibility.

### Modified Capabilities

- `event-temporal-integrity`: Permit an entirely absent submission interval only with false mode; retain all existing chronology, retrieval, upcoming, and inclusive-range requirements.
- `event-temporal-input-validity`: Civil-date mode, Gregorian validity, temporal input mutual exclusion, and shared normalization while retaining the existing timed lexical contract.
- `content-submission-draft-persistence`: Checkpoint/recovery of the temporal mode and final civil date, with missing `allDay` defaulting to false only for otherwise supported drafts.
- `content-submission-server-idempotency`: Atomically persist the mode with the first commit and preserve it on replay; omitted RPC flag defaults to false.
- `submission-promotion`: Copy the temporal mode atomically with event dates under the existing promotion lock and readiness checks.
- `content-submission-submit-orchestration`: Extend the exact public wire-envelope requirement with `all_day`, `start_calendar_date`, and `end_calendar_date`. Existing attempt ownership, captured-state, upload, retry, and retirement guarantees remain intact.

## Impact

- Forward Supabase migration, `submit_content`, `promote_content_submission`, shared `submission_dates.ts`, public/Admin validation and stores, explicit Admin row projections, generated database types, and importer submission writes.
- `EventTimePolicy`/`EventDateDraft`, Event/ContentSubmission models, wire/DTO/entity mappers, draft storage, ObjectBox generator inputs, public/Admin editors, event display consumers, and focused backend/Flutter regressions.
- No new packages, general temporal/importer framework, published-event editor, cross-provider deduplication, half-open conversion, “Eventi in corso”, forced update/version routing, historical reclassification, or unrelated refactor. The existing unimplemented Admin-editor-workflow change is an adjacent planning dependency to coordinate, not part of this scope.
