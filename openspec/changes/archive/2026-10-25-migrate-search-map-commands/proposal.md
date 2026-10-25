# Proposal

## Why

The fourth change in Draft PR #12's cumulative migration replaces seven remaining legacy Commands in Search history and GeoMap filters/markers. A mechanical substitution would leave bootstrap/history races, inconsistent marker snapshots and failures indistinguishable from loading or empty results.

## What Changes

- Migrate history add/load/remove to the existing ResultCommand factories: one reader and a private writer with a feature-local ordered FIFO. The writer synchronously accepts valid intentions during pending writes, preserves per-operation optimism/rollback and settles accepted obligations after UI navigation/disposal.
- Replace four GeoMap Commands with two synchronous setters and one restartable marker load using immutable snapshots, atomic commits, explicit partial outcomes and current-filter retry.
- Adapt actual consumers and verify deterministic concurrency, error, disposal, SearchAnchor popup, filter, navigation and owner-replacement regressions.
- **BREAKING** (internal Dart APIs): remove loadEvents/loadPlaces and Command-shaped GeoMap setters; adapt all callers. History add/remove dispatch intentions to the local FIFO. Proven duplicates may be no-ops; opposite intentions and different entries retain acceptance order. Serialization is session-local, without ObjectBox changes or cross-owner ordering guarantees.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: history admission, ordered persistence independent of UI lifecycle and revision-aware reconciliation; marker authority, snapshots, empty state and retry.
- `local-content-retrieval`: atomic marker outcomes, ordering and partial results with errors, distinct from existing Nearby contracts.

## Impact

Implementation covered SearchViewModel, GeoMapViewModel, AppSearchAnchor, GeoMapScreen and relevant tests/support. ExploreScreen and SearchResultScreen consumers stopped redundantly closing the popup. GeoMapBottomSheet remained a regression surface with its existing state ownership. GeoMapUseCase and SearchRepository remained existing boundaries; persistence, backend, dependencies and foundation were unchanged. Search loadResults/loadSuggestions, GeoMap loadNearContent/selectContent, mode, Post, Weather, Search admission fence and route ownership remained outside migration.

## Planning history and implementation evidence

The authorized baseline was `1f3753b10c18061c6655cb32d078bf93aff1b05e`, with three migrations already implemented. Planning, F1–F5 remediation, independent plan review, authorization, implementation and independent code review were completed. The Apply sections of `design.md` record historical implementation checks; `tasks.md` records 27 verified tasks.

F1–F5 superseded initial decisions that lost submissions before deferred action entry, dropped opposite mutations or invalidated bootstrap too late. The corrected protocol also reconciles runtime failures. Dialog drafts still apply on permitted route completion (Save, Back, barrier/drag), only for mounted/current State and session; no cancellation semantics were added. Historically unchecked planning tasks were checked after implementation verification.

## Published checkpoint and current cumulative status

Git records checkpoint 4 as `da7c426fb799a26094f043319b47e63b98728f92`, parent `1f3753b10c18061c6655cb32d078bf93aff1b05e`. Documentation reconciliation `f48a08946c9ac40146104a0157556243ad433c92` followed directly and corrected its publication status. Both are published in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12).

The checkpoint-4 status was historically **4/7 implemented and published**, with 66 INFO remaining. The cumulative PR now contains **seven published migrations**; that later status does not make checkpoint 4 analyzer-clean. Canonical synchronization, archival, legacy compatibility deletion and merge require separate authorization. PR #12 remains Draft; merge is not authorized.
