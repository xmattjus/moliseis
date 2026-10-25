> Historical proposal: the implementation was completed in `9e2f49ed2956ff641423610d56b68b6217535dce`; the contract clarification followed in `05b0f9e3432462a2fbf86c84dc4b6f80e0ed4ab9`. Planning-time observations and future-tense actions below describe those earlier checkpoints. See implementation-evidence.md for historical verification and reported operational outcomes.

## Why

Canonical content sync currently fetches entire Supabase tables without pagination, even when almost nothing changed, and can silently stop at the server row cap. Reusing the existing semantic modification marker with paginated bootstrap/delta retrieval reduces remote transfer while retaining the two-phase, concurrent-fetch, atomic local-commit and offline-cache behavior.

## What Changes

- Define table-specific semantic `modified_at` contracts for cities, places, events and media, including deletion/restoration, strict per-row growth and DB-owned UPDATE markers. Normalize legacy tombstones before activating replacement triggers; change only canonical INSERT marker defaults to `clock_timestamp()` and add four ordinary B-tree marker indexes.
- Add stateless invoker RPC `get_content_sync_cursor()` and a minimal inward-facing cursor source; capture its server timestamp before retrieval without imposing a query upper bound.
- Add nullable ObjectBox `AppSettings.contentSyncCursorAt`, separately from device completion/scheduling `lastSyncedAt`; preserve existing UIDs and prove genuine previous-store compatibility. Persist both timestamps through one checked `setSyncState` operation.
- Force full paginated bootstrap when the cursor is absent, then retrieve inclusive deltas from cursor minus 24 hours. Share one focused ID-keyset pagination helper with page size 500, terminating only on an empty page.
- Replace the special deletion merge branch with full mapper merges gated by freshness; fix City deletion mapping and retain Event/Place saved state, batching and cross-repository rollback.
- Preserve three-day scheduling, existing first-sync fatal classification, Result boundaries and Provider wiring. Return sync failure on settings-save failure after content commit and support harmless replay.
- Clarify the external provenance restore boundary: canonical persistence/sync remains restore-capable with low-level regression coverage, while no supported Event restore operation or provenance restore producer is introduced.
- Require backend-first rollout and deterministic DB/client compatibility, failure and concurrency regression gates. After local ObjectBox upgrade, any operational full-sync rollback release must preserve the current model/UIDs and contentSyncCursorAt; compatibility with the exact pre-change binary/model is not promised. No rollback implementation is introduced.
- Bind cursor authority to the projection/materialization contract that advanced it. Future projection expansion requiring historical remote state must reconcile that state before reusing the cursor; no runtime versioning or infrastructure is added. This contract clarification adds no production implementation.

## Capabilities

### New Capabilities

- `canonical-content-sync`: Semantic canonical markers, legacy normalization, server cursor, paginated bootstrap/delta retrieval, idempotent local merge, atomic commit, durable local cursor and compatibility/failure behavior. Existing specs contain no canonical sync capability; `local-content-retrieval` governs local discovery and must not be broadened into replication.

### Modified Capabilities

- `external-event-provenance-moderation`: Clarify generic lifecycle/sync restore support versus the absence of a supported Event restore workflow, retaining the future linked-source enqueue obligation.

Existing Event temporal/all-day, submission promotion, other external provenance/moderation and Command contracts remain in force and are regression gates.

## Impact

Analyzed local and remote `main`: `8d7724960889a4224c11f8a2c58d31d8c1c945c7` (remote verified during planning; no advancement from supplied baseline). The working tree was clean before this change. Remediation reverified local and remote `main` at `18ff4ff09427b7675750639d646e32bc68adbf9f`, the review commit containing these artifacts; no intervening production changes were found.

Apply will affect a new Supabase migration, persistent canonical marker column comments, DB tests and regeneration of `supabase/functions/_shared/database.types.ts` from the migrated local schema; `Synchronizable`, `BaseSyncRepository`, four repository implementations and the City mapper; `AppSettings` and generated ObjectBox bindings/model; Settings repository; `SyncUseCase` and its composition in `config/dependencies.dart`; shared fakes/HTTP test support and focused regressions. Add only one pagination helper and one cursor interface/implementation, with no package or DI framework changes. Backend migration is compatible with installed full-sync clients; a new client requires the cursor RPC and fails explicitly if it is missing.

Out of scope: new marker columns, counters/sequences, CDC/WAL/Realtime/change logs, per-table cursors, patches, hard-delete propagation, Event restore UI/workflow, locks, caching layers, background sync, frequency changes, new dependencies, general refactors, or changes to `content_submissions.modified_at` and `external_event_records.modified_at`.
