## Why

At the start of planning, six ordinary operations still depended on deprecated legacy Commands although Result-aware command_it factories already existed. This first migration preserves feature behavior and makes admission, outcomes and lifecycle explicit without reproducing the legacy API.

## Published checkpoint

Implementation and post-apply remediation were published in commit `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, parent `ee60777c7fdfc5c16daa1151050c134fbb7cde29` (2026-10-20). Git history verifies this relationship. The checkpoint is included in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12). All seven migrations are now published; this record was added after publication and does not claim that the commit recorded its own SHA. Historical planning and local apply records below and in design.md retain their original temporal scope. The legacy compatibility implementation remains; removal, canonical synchronization, archival and merge require separate authorization.

## Implementation evidence

The authorized apply ran on 2026-10-20: five ViewModels, six Commands, four consumers and related tests/support. Independent review then identified CR-F1 (Sentry consent after disposal), CR-F2 (document status) and CR-F3 (overbroad test wrappers). Remediation reconciled consent from the repository cache and removed wrappers without a reproduced need. The final historical validation and verdict are in design.md and tasks 7.1–7.3. These records do not authorize merge.

The planning findings F1–F6/R1–R3 below are distinct from post-apply CR-F1–CR-F3. At that planning checkpoint none of the other six changes had started.

## What Changes

- Migrate only SettingsViewModel.setCrashReporting; ThemeViewModel.setThemeBrightness/setThemeType; ExploreViewModel.loadLatest; SuggestionViewModel.load; FavouriteViewModel.load: **5 ViewModels, 6 Commands**.
- Adapt necessary consumers/tests; observe command.results through ResultCommandSnapshot and use run/runAsync according to actual waiting needs. No implicit latest-intent behavior.
- Preserve Settings/Theme optimism and rollback, feature-specific Explore/Suggestion retention, progressive Favourite publication and membership. setFavourite remains Future<Result<void>> without another Command.
- Guard local commits, notifications, rollback and new repository phases after disposal. Always schedule cleanup outside dispatch, including idle Commands; retain active Commands until safe settlement and recheck, preserving global reporting.
- Correct Settings feedback: a failed write must not show success. No other intentional UX change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: authorized **MODIFIED** delta for `Only authoritative completion can commit asynchronous data`, distinguishing restartable lanes from ordinary single-flight operations; add observable contracts for these operations, feedback, Favourite admission and lifecycle.

Search/GeoMap retain separate retrieval and synchronous authoritative commit, with no stale publication. Ordinary operations may retain live authoritative optimistic/progressive continuations. Canonical specifications are not directly changed; `local-content-retrieval`, routing and navigation-shell remain binding. No artificial preferences/favourites capability.

## Impact

Implemented production scope: five ViewModels, SettingsScreen, ExploreScreen latest section, SuggestionHorizontalListView and FavouriteScreen. FavouriteButton remains a Provider consumer of isUpdating/membership with its direct API unchanged. Provider scope/composition is unchanged. Tests cover the five ViewModel suites, relevant widgets and Provider/router consumers including sync_redirect_test.

### Historical planning baseline and diagnostics — 2026-10-19

Initial preflight/remediation: repository xmattjus/moliseis; HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`; fetched origin/main `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, matching the requested baseline. That checkout was 0 ahead/7 behind and was not the future implementation base.

Analysis of that main snapshot actually produced 125 legacy INFO, zero warnings/errors. R3 in design.md records the direct Dart `analyze --format machine` command, cwd, defaults, SDK, temporary package_config adaptation and historical exit 0; a separate replay measured raw exit 0 and byte-identical output. This exit does not belong to flutter analyze and is not inferred from counts. Scope: **12 target diagnostics** (Theme 4; Settings, Explore, Suggestion, Favourite 2 each), leaving **113**, including eight Category diagnostics. Identity/multiplicity comparison, rather than balance alone, was required. Resolved versions: command_it 9.5.2, listen_it 6.0.0, Flutter 3.47.5, effective Dart 3.13.4; no dependency upgrade.

The remediation checkout already contained modified AGENTS.md and untracked directories for this change and PR4, with an empty index. These unrelated changes were preserved. .openspec.yaml remained spec-driven without skip_specs.

### Historical F1 resolution and migration sequence

Category and its four operations/consumers/tests were excluded: deferred factory action entry needed feature-specific coordination. They were reserved for the independent `migrate-category-view-model-commands` change, without a preparatory adapter, scheduler, wrapper or factory here.

The user requested **seven sequential OpenSpec changes on one branch and one integration PR**, without a coordination change. This first change did not depend on implementing the others. The original plan associated global zero deprecations and command.dart removal with final integration; the later authorized scope retained compatibility code and requires separate authorization for deletion.

### Historical gates, risks and non-goals

Acceptance required six migrated Commands, five legacy-free ViewModels, 12 removed identities and 113 preserved, no new diagnostics, unchanged domain/persistence contracts, only the declared Settings feedback correction, preserved single-flight and distinct application/runtime outcomes, no post-dispose presentation commits/notifications, and passing focused plus full Flutter tests.

Design risks include deferred preference action entry without a same-stack consumer requirement, synchronous Favourite admission including a write that finishes before load entry, guards after reentrant notify, and always-deferred exactly-once cleanup (R1). Independent Theme lanes share SettingsRepositoryImpl and retain its pre-existing concurrent-snapshot lost-update risk (R2). No persistence atomicity/serialization guarantee, mutex, queue or coordinator was added; PREF tests establish local state/rollback per lane, not persisted merging. Apply and post-apply results are separate design records.

The 2026-10-19 documentation remediation changed only four artifacts, leaving metadata, code/tests/support, dependencies/analyzer/CI/backend/generated files, global logging, canonical specifications and unrelated plans untouched. There was no apply/commit/push/PR/merge/archive in that phase. F1 was resolved by authorized exclusion, F3 by the MODIFIED delta and F2 by a concrete strategy/regression gate. Its **READY FOR INDEPENDENT REVIEW** verdict was neither plan approval nor apply authorization; later implementation is recorded separately.
