## Why

`GeoMapScreen` still owns `_selectedContent`, `_searchQuery` and `_pendingSelection` while its ViewModel owns routed selected content. The sheet infers semantic presentation from these competing values. Shared Nearby and Weather data can also outlive the content/coordinate target that requested them.

Original planning baseline was `58544bca16f3e826ae01ff90fc3442a014325892`. Remediation audit verified local HEAD `4f6de14be7f3e4f7b3f068ed453845dfce808f2b`, a descendant of that baseline, with only this untracked planning directory in `git status --short`. `adopt-command-it-restartable-foundation` is implemented, including unified GeoMap selection and independent Search lanes, but remains active and unsynchronized. This change reuses those guarantees instead of implementing them again.

## What Changes

- Introduce one immutable ViewModel-owned `GeoMapMode`: `GeoMapExplore`, `GeoMapSearchResults(query)` or `GeoMapPostDetail(identity)`; async status remains in command snapshots.
- Separate Post identity from matching `resolvedContent`; already-materialized marker/Search/Nearby selection performs no repository lookup.
- Integrate existing `GeoMapSelectionIntent` and `selectContent` with the mode. Keep one cross-type lookup ownership domain and fetch/commit separation; no new restartable primitive or per-action revision counters.
- Supply one nullable complete routed identity. Apply it on identity-by-value OR GeoMap owner change; equal identity/equal owner does not reopen a locally dismissed Post.
- Own a committed Explore anchor separately from the local live camera. Bind one restartable Nearby lane to either Explore anchor or selected Post identity/coordinates, preserving Places-first, Events-second retrieval and partial data plus first error; one synchronously cleared committed terminal also represents unexpected failure.
- Remove legacy Command types from the shared Nearby widget boundary using a listener, target key, load callback and one coherent presentation projection; adapt normal Post call sites without migrating PostViewModel behavior.
- Bind WeatherViewModel's current/hourly/daily lanes to one semantic content/coordinate target written only by the containing screen; Button/modal requests cannot change it. Reuse restartable execution for these three lanes, invalidate all on target change, retain automatic current and lazy modal forecasts, and remove obsolete occupied-command waiting in the button.
- Keep existing Search latest-intent behavior. Only valid committed queries enter GeoMap SearchResults; mode transitions revoke pending Post/nearby authority.
- Guard delayed camera and presentation effects against newer movement, semantic intent, owner replacement and disposal. One presentation observer checks exact immutable mode/materialization references, including reentrant equal-value intents. Preserve sheet extents, content centering and explicit close; remove the confirmed dead scrim renderer/state.
- Preserve Provider/ChangeNotifier, repository filtering/distance behavior, Result error distinctions, shell/branch ownership, restoration, system/predictive Back, full-screen Gallery and local selection without URI rewriting.

## Capabilities

### New Capabilities

- `geo-map-semantic-state`: authoritative GeoMap mode, materialized Post invariants, route input ownership, Search integration, Weather target consistency and camera/effect lifecycle.

### Modified Capabilities

- `command-execution-concurrency`: modify the complete existing Weather initialization requirement to replace single-flight settlement waiting with guarded restartable admission and common target ownership.
- `local-content-retrieval`: add the genuine shared GeoMap Nearby target and aggregate-outcome contract. Existing Home and foundation Search requirements remain unchanged; no duplicate Search delta.

## Impact

Future apply touches GeoMap ViewModel/selection intent/screen/sheet/modals, router's Map identity construction, WeatherViewModel/button/modal/hourly/daily consumers, shared Nearby widgets and the normal PostScreen adapter call site, the existing modal helper’s optional synchronous route-capture parameter, plus focused integration tests. Planned feature types and exact boundaries are in design.md. Existing `lib/utils/restartable_command.dart` and `lib/utils/result_command.dart` are reused without modification; ordinary unrelated legacy commands remain outside scope.

No backend, SQL, RPC, Edge Function, repository query, ObjectBox schema, generated output, dependency, state-management or navigation redesign. Supabase `events` and `places` have separate row identities: `(positive remoteId, ContentType)` remains complete content identity.

Pre-apply gate: synchronize/archive completed foundation capabilities through a separately authorized workflow, then revalidate this additive retrieval delta and complete Weather MODIFIED requirement against canonical specs. The sixth authorized artifact resolves the former formal Weather conflict; this remediation performs no foundation synchronization/archive. External adversarial review is next, not production apply.
