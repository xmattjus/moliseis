## Why

The Compass-derived Command drops new requests while running. Search consequently loses newer queries; GeoMap needs shared generation guards and route retries to approximate latest-wins. Adopt audited command_it lifecycle and error routing, adding only the missing restartable policy.

## What Changes

- Add direct `command_it: ^9.5.2` and `stream_transform: ^2.1.2` dependencies during apply, following the current caret policy and synchronizing the lockfile.
- Introduce nullable Result integration through thin factories/extensions; preserve never-run, running, success, domain error and unexpected error separately. New code uses run/runAsync/isRunning/isRunningSync.
- Introduce one composed RestartableCommand using switchMap and per-execution command_it children, immediate authority revocation, nonblocking subscription cancellation and deferred ordinary-child cleanup. ProgressHandle specialization is deferred until a real consumer defines its expected cancellation contract.
- Migrate Search loadResults/loadSuggestions and GeoMap's unified event/place/clear selection boundary. Separate asynchronous retrieval from synchronous authoritative ViewModel commits. Adapt only WeatherForecastButton init/update lifecycle for changed forecast owner/target; GeoMapScreen remains responsible for owner disposal/rebinding and does not initialize forecasts.
- Preserve upstream assertion-failure development policy; route handled unexpected runtime command errors once through existing AppLogger/Talker/Sentry, preserving opt-out and stack traces and excluding parameters.
- Remove only proven redundant selection generations and dropped-command retries. Keep legacy Command for excluded consumers, including history writes, Post and other domain coordinators/mutations.
- Record baseline, upstream audit, complete consumer inventory and a second-wave migration ledger. The stale unimplemented admin change is a future re-audit item, never a predecessor.

## Capabilities

### New Capabilities

- `command-execution-concurrency`: Result-aware command state, reporting, composed restartable execution, lifecycle and first-wave selection ownership.

### Modified Capabilities

- `local-content-retrieval`: Search results and suggestions explicitly become latest-intent-wins while preserving repository behavior, atomic publication and short-query collection semantics.

## Impact

Production scope is utility infrastructure, startup logging configuration, Search ViewModel/UI/call sites and GeoMap selection ViewModel/screen plus WeatherForecastButton current-forecast lifecycle. WeatherViewModel and its legacy commands remain unchanged. Provider, ChangeNotifier, repository/use-case contracts, routing identity and backend contracts remain authoritative. Exact files and tests are enumerated in design.md and tasks.md.

No production code or dependencies are changed by this planning session. No Bloc/Riverpod/get_it/watch_it/flutter_it, backend changes, queue/retry framework, restartable runAsync, nearby redesign or broad consumer migration. The pre-existing untracked `harden-geo-map-semantic-state` plan overlaps and proposes incompatible infrastructure; it is left untouched and must be reconciled separately before its own apply.
