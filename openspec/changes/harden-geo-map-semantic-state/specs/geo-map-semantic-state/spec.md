## Purpose

Keep Map semantic presentation and target-bound content coherent across route inputs, local selection, discovery, forecasts and delayed UI effects while preserving established navigation ownership.

## ADDED Requirements

### Requirement: GeoMap exposes one authoritative semantic mode

GeoMap SHALL represent presentation with exactly one immutable ViewModel-owned mode: Explore, SearchResults with one committed valid query, or PostDetail with a complete positive ID and content type identity. Async neutral/running/success/error SHALL remain in execution snapshots rather than additional modes. Selection requests SHALL be transient inputs, not competing stored modes. Coupled mode, resolved content and active discovery target changes SHALL be coherent before a single semantic notification.

#### Scenario: Default Map opens
- **WHEN** Map is entered without a valid complete routed identity
- **THEN** it presents Explore

#### Scenario: Valid search is submitted
- **WHEN** a query satisfying the unchanged existing Search validity predicate is committed
- **THEN** GeoMap enters SearchResults with that exact query and independent execution status

#### Scenario: Post identity begins resolving
- **WHEN** a complete routed identity is accepted without materialized content
- **THEN** GeoMap immediately enters PostDetail for that identity with absent resolved content and current loading presentation

### Requirement: Materialized Post content matches the active Post identity

Non-null resolved content SHALL exist only for current PostDetail and match both its remote ID and Event/Place type. Already-materialized selection SHALL synchronously commit identity and content without repository lookup. Repository identity mismatch SHALL be rejected before any materialized commit.

#### Scenario: Marker content is already available
- **WHEN** a complete marker, Search result or Nearby result is selected
- **THEN** GeoMap commits PostDetail and matching resolved content together with zero identity lookup

#### Scenario: Routed content resolves successfully
- **WHEN** authoritative retrieval returns content matching current identity
- **THEN** it becomes resolved content without a separate Ready mode

#### Scenario: Repository returns the wrong identity
- **WHEN** current retrieval returns a wrong ID, type or malformed null payload
- **THEN** no invalid content is published, Explore fallback and one existing not-found feedback occur, and no retry lookup is automatically issued

### Requirement: Presentation mechanics remain widget-local

Camera/controllers/sheet extents/animations SHALL remain widget-local. GeoMapViewModel SHALL separately own the committed Explore anchor. Delayed settle/effect callbacks SHALL be rejected after newer relevant movement, semantic intent, owner replacement or unmount. Programmatic Post centering SHALL NOT commit an Explore anchor.

#### Scenario: User pans the map
- **WHEN** live movement has not settled
- **THEN** camera position changes locally while committed Explore anchor remains unchanged

#### Scenario: Explore movement settles
- **WHEN** the latest genuine Explore movement survives the existing debounce with the same live owner
- **THEN** its center becomes committed Explore anchor and Nearby target

#### Scenario: New movement begins during debounce
- **WHEN** center A is waiting and movement toward B begins before A's delay expires
- **THEN** A cannot commit, including before B's movement ends

#### Scenario: Post centering or obsolete effect
- **WHEN** a programmatic Post move occurs or a delayed effect belongs to an older mode/owner
- **THEN** it cannot commit Explore coordinates or affect the current sheet/camera/feedback

### Requirement: New semantic intents supersede older Post resolution

GeoMap SHALL reuse the established cross-type latest-intent selection domain. New routed Post, materialized selection, valid Search or Explore intent SHALL immediately revoke obsolete Post publication authority. Async retrieval SHALL have no post-await ViewModel mutations; only authoritative live synchronous completion may commit.

#### Scenario: Routed Post A is replaced by routed Post B
- **WHEN** pending A is superseded by B of the same or another content type
- **THEN** B is admitted immediately and late A success or failure cannot change content, mode, running or feedback

#### Scenario: Search replaces pending Post
- **WHEN** valid Search is committed while Post retrieval is pending
- **THEN** the old Post cannot reopen or populate resolved content

#### Scenario: Explore replaces pending Post
- **WHEN** explicit close or default Map supersedes pending retrieval
- **THEN** its later completion leaves Explore unchanged

#### Scenario: Owner is disposed
- **WHEN** retrieval completes after GeoMap owner disposal
- **THEN** no result forwarding, state commit, UI effect or late ViewModel notification occurs

### Requirement: Post resolution failures retain authoritative terminal evidence

Expected repository error, identity contract rejection and handled unexpected runtime failure SHALL remain distinguishable. Current terminal failures SHALL clear Post data, fall back to Explore and preserve the authoritative terminal snapshot until another intent, allowing existing not-found feedback once. Stale failures SHALL produce no feedback. Unexpected failures SHALL retain foundation reporting; assertions SHALL retain fail-loud behavior rather than ordinary fallback feedback.

#### Scenario: Current expected error
- **WHEN** authoritative Post retrieval returns an expected repository error
- **THEN** Explore fallback commits the actual live camera center and matching Nearby target without automatic recentering or erasing the error snapshot before feedback observes it

#### Scenario: Resolution fails after camera movement
- **WHEN** a routed Post fails while the camera has moved from committed anchor A to center B
- **THEN** Explore commits B and Nearby targets B without moving the camera; obsolete A debounce/results cannot replace B, and further genuine movement realigns all three after settle

#### Scenario: Stale runtime failure
- **WHEN** old physical retrieval throws a handled runtime failure after newer intent
- **THEN** foundation reporting remains intact and current semantic state/feedback are unchanged

#### Scenario: Listener reentry during fallback
- **WHEN** a synchronous listener admits equal-value Explore, new Post intent or local materialized selection during fallback notification
- **THEN** the old failure cannot schedule feedback or presentation for the superseding mode, even before deferred command snapshots update

#### Scenario: Current runtime failure and assertion
- **WHEN** authoritative retrieval throws a handled runtime failure or a fail-loud assertion
- **THEN** the handled failure retains unexpected-error evidence with current fallback feedback, while assertion policy remains fail-loud without fabricated domain error/not-found feedback

### Requirement: Route selection is applied only on semantic route-identity change

Routing SHALL supply one nullable complete identity, preserving validation/default fallback. Route semantics SHALL be reapplied when identity changes by value OR GeoMapViewModel instance changes. Equal identity/equal owner SHALL not resolve twice or reopen locally dismissed presentation. Route restoration SHALL retain the existing URI contract.

#### Scenario: Same identity rebuilds
- **WHEN** unrelated router/widget refresh rebuilds the same identity and owner, pending or settled
- **THEN** it admits no new selection, refetch, mode reset or reopening after local dismissal

#### Scenario: Same URI receives new owner
- **WHEN** GeoMap owner changes with unchanged route identity
- **THEN** new owner resolves it once and old callbacks cannot affect the new selection

#### Scenario: Route returns to default Map
- **WHEN** identity is removed or becomes invalid/partial
- **THEN** GeoMap enters Explore, revokes pending resolution and restores default sheet extent

#### Scenario: Lifecycle route preparation and deferred admission
- **WHEN** init/update changes route identity or owner while Flutter is building
- **THEN** obsolete Post/Nearby/Search/Weather authority is revoked and old content is hidden immediately without synchronously notifying Provider or UI builders; only the still-owned post-frame route admission publishes/starts lookup

#### Scenario: Route returns to A before frame admission
- **WHEN** routed A changes to B and then A before deferred admission runs
- **THEN** only the final exact preparation/token admits A, the earlier A cannot regain authority by value equality, and obsolete completion cannot commit or produce feedback

#### Scenario: Already initialized default or deferred owner disposal
- **WHEN** a new owner already presents correct default Explore, or a queued admission loses its owner/screen before execution
- **THEN** the default avoids a redundant transition and lost admission performs no lookup, controller access, notification or effect

#### Scenario: Marker selects content locally
- **WHEN** marker/Search/Nearby selection enters local PostDetail
- **THEN** Map URI remains unchanged

### Requirement: GeoMap Search integrates existing query ownership

Search SHALL retain its foundation independent result/suggestion, short-query and atomic publication guarantees. Only valid committed queries SHALL enter GeoMap SearchResults. Visible results and loading/error presentation SHALL belong to the latest Map admission for the exact current Search mode and Search owner, including repeated equal queries. Query equality or synchronous non-running state alone SHALL NOT authorize an older terminal snapshot. Each Map submit/retry SHALL synchronously fence out the pre-admission public snapshot; neutral/loading and unpublished terminal intervals SHALL not expose retained collections. The newest authoritative publicly published terminal SHALL eventually render success or failure for that admission. Shared SearchViewModel and SearchResultSliverList behavior SHALL remain unchanged.

#### Scenario: Invalid query submitted
- **WHEN** a short query is submitted while a different semantic mode is active
- **THEN** no invalid SearchResults mode or Map result-lane request is created, current mode and matching snapshot remain coherent, and existing Search callers retain their short-query no-op invalidation semantics

#### Scenario: Search result selected
- **WHEN** complete result content is selected
- **THEN** GeoMap enters materialized PostDetail without repository lookup and pending Post/discovery authority is revoked

#### Scenario: New valid query loading or failing
- **WHEN** valid query B supersedes A
- **THEN** SearchResults(B) displays B's snapshot loading/error/success and never A's retained collection as B

#### Scenario: Same query admitted after completed Search
- **WHEN** A completes, Post is opened, and A is submitted again before deferred loading publication
- **THEN** the previous completed A snapshot and collection cannot render as the new admission; the new Search surface shows loading

#### Scenario: Logical completion precedes public terminal
- **WHEN** the latest Search execution has lowered isRunningSync but its terminal public snapshot has not yet published
- **THEN** the excluded pre-admission snapshot or still-public loading/neutral snapshot cannot render results, even when query strings are equal

#### Scenario: Latest same-query terminal publishes
- **WHEN** the newest accepted A publishes success, empty success or expected/unexpected terminal failure
- **THEN** that admission renders its current collection or existing error/retry presentation and never the prior A collection

#### Scenario: Equal submit or retry reenters publication
- **WHEN** repeated equal submissions, retry, or synchronous listeners supersede Search with another Search mode or Post/Explore during admission/publication
- **THEN** only the exact latest mode/owner fence may render or act on results; an obsolete retry/result callback cannot restore a replaced surface

#### Scenario: Search presentation owner changes or unmounts
- **WHEN** Search/GeoMap owner changes or the Screen unmounts
- **THEN** its old fence and callbacks lose authority; retained Search on a new Search owner initializes the current query once through fresh guarded admission, while equal owner/mode rebuilds do not refetch

### Requirement: Weather streams share one authoritative target

Weather SHALL bind all current/hourly/daily data and publication to one value target containing content identity and coordinates. Target change or clearing SHALL revoke all three lanes and reset old projections before another Post can render them. Each lane SHALL use existing latest-intent execution with fetch/commit separation. Owner/init/update guarantees and API/cache contracts SHALL follow the complete modified Weather requirement in command-execution-concurrency; GeoMap binds the target from authoritative materialized mode and never initializes forecast I/O.

#### Scenario: Local Post changes within one Weather owner
- **WHEN** Post A changes to B while any A forecast is pending or stored
- **THEN** all A lanes lose authority, old projections are hidden immediately and B current forecast starts without waiting for A settlement

#### Scenario: Lazy hourly and daily forecasts
- **WHEN** B becomes current without opening its Weather modal
- **THEN** current is initialized once and hourly/daily remain neutral until modal opening; opening requests both for B

#### Scenario: Hourly or daily completes for old target
- **WHEN** A hourly/daily completes after B or no Post becomes authoritative
- **THEN** it cannot populate B or appear with B's current conditions

#### Scenario: Weather owner replacement
- **WHEN** unchanged content receives a new Weather owner
- **THEN** current initialization occurs once for the new owner without another GeoMap lookup, and old-owner completion/modal cannot affect it

#### Scenario: Rebuild and retry
- **WHEN** equal owner/target rebuilds or a failed forecast is explicitly retried
- **THEN** rebuild causes no extra admission, while retry runs the failed lane for the still-current target

#### Scenario: Target returns before the next frame
- **WHEN** a retained forecast widget sees A→B→A or A→no target→A before frame admission
- **THEN** A's neutralized current lane is initialized once despite a historical prior A admission, without displaying old data

#### Scenario: Open modal loses target or owner
- **WHEN** the modal's captured target/owner is invalidated
- **THEN** all forecast/title projections are gated and the owning Button releases only its captured modal route, without popping a newer or parent route or requiring disposal-time ViewModel notification

### Requirement: GeoMap preserves established local navigation behavior

This change SHALL preserve shell/branch ownership, URI restoration, explicit Search/Post close, system and predictive Back and full-screen Gallery. One-shot effects SHALL retain Explore extent 0.3, Search 1.0 and Post 0.5 with existing centering, without introducing semantic animation state.

#### Scenario: System or predictive Back with transient Map surface
- **WHEN** system Back or predictive Back is dispatched or cancelled with transient Search/Post state
- **THEN** existing route-stack and cancellation behavior remains, without substituting a semantic mode reset

#### Scenario: Explicit close is used
- **WHEN** Search/Post sheet explicit close is activated
- **THEN** GeoMap enters Explore at the actual live camera center, clears search input and restores Explore sheet extent

#### Scenario: Listener reentry during successful materialization
- **WHEN** a synchronous listener admits a new equal-identity materialized Post or Explore before or after the presentation observer sees resolved content
- **THEN** only the current exact mode/materialization may cause camera/sheet effects; unrelated collection notifications and Explore anchor settle do not repeat entry animation

#### Scenario: Gallery is opened
- **WHEN** media opens Gallery from Map Post
- **THEN** Gallery remains full-screen on the existing root navigator and return preserves established Map behavior
