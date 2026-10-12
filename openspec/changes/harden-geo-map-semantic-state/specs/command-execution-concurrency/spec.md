## MODIFIED Requirements

### Requirement: Forecast widget owns current-weather initialization across updates

The current-weather widget SHALL own automatic initial and updated owner/target forecast requests. The containing Map or ordinary Post screen SHALL bind the Weather owner to the current authoritative content identity/coordinates and retain its established owner disposal/rebinding responsibility; screens SHALL NOT initialize forecasts. Deferred widget or modal requests SHALL NOT change that binding. Replacing the Weather owner or changing semantic content identity/coordinates SHALL initialize current weather for the current target exactly once; unchanged owner/identity/coordinates rebuilds SHALL NOT request again. Initial/update callbacks SHALL avoid duplicate admission and recheck current owner and target at request admission, since mounted alone does not establish semantic freshness.

A new target SHALL immediately revoke current/hourly/daily publication authority and reset old target projections. Latest current-weather work SHALL be admitted without waiting for obsolete physical Futures. Superseded results SHALL NOT publish into the new target; independent forecast lanes SHALL all respect the same target binding. Hourly/daily SHALL remain lazy until modal opening. Expected failures, unexpected runtime errors, fail-loud assertions and restartable child cleanup SHALL follow the unchanged general foundation execution contract. Disposal SHALL detach completion observers and stop forwarding without notifying during owner teardown or prematurely disposing live ordinary children.

Each WeatherForecastButton instance SHALL synchronously admit at most one outstanding modal before lazy forecast requests or route push, including the interval before its builder executes and the exit transition. Rejected openings SHALL perform no hourly/daily requests or navigation. Target/owner change SHALL revoke that opening and release only its exact route while retaining the admission guard until full closure. Modal Future completion and captured route transition completion SHALL safely release only the matching opening token; stale callbacks SHALL NOT clear newer ownership. A fully closed modal SHALL permit another valid opening. Disposal SHALL leave deferred completion/dismissal unable to access unmounted State/context or an invalid Navigator.

An open modal SHALL remain bound to its captured content/target and owner, SHALL NOT display another target's data, and SHALL be safely released when its owning forecast widget changes target/owner or is removed. Such release SHALL affect only that modal route, never a newer or parent route. Weather API/cache behavior SHALL remain unchanged.

#### Scenario: Initial owner
- **WHEN** the forecast widget mounts with a bound content target
- **THEN** it requests current forecast once using the current coordinates

#### Scenario: Same widget receives new forecast owner
- **WHEN** the retained widget receives a new Weather owner for unchanged content/coordinates
- **THEN** the new owner receives one current-forecast request without another Map content lookup, and the widget observes the new owner only

#### Scenario: Unchanged target rebuild
- **WHEN** owner, semantic content identity and coordinates are unchanged on rebuild
- **THEN** no additional current-forecast request occurs

#### Scenario: Changed target during same-owner pending request
- **WHEN** a retained widget changes content identity or coordinates while the same owner's old request is physically pending
- **THEN** the newest bound target becomes authoritative immediately, current forecast can start without waiting for old settlement, and old-target data cannot publish or render as the new target's weather

#### Scenario: Changed target after completion
- **WHEN** a retained widget changes content identity or coordinates after the prior request settles
- **THEN** it requests forecast for the new target once, even if the previous command completed or failed

#### Scenario: Old owner completes late
- **WHEN** the previous owner completes after replacement
- **THEN** it cannot change the new owner's state or widget observations, and no lifecycle exception or late owner notification occurs

#### Scenario: Update before initial deferred request
- **WHEN** owner or target changes before the initial request callback runs
- **THEN** only the still-current owner/target is requested once, and the old callback cannot restore or restart the old target

#### Scenario: Cross-lane invalidation and laziness
- **WHEN** target A changes to B with A current/hourly/daily data pending or stored
- **THEN** all A lanes lose authority and their projections reset, B current initializes, and B hourly/daily remain neutral until its modal is opened

#### Scenario: Target returns before deferred admission
- **WHEN** A changes to B or no target and returns to A before deferred widget admission
- **THEN** A's neutral current lane initializes once rather than being skipped because of a historical A request

#### Scenario: Obsolete modal request
- **WHEN** a still-mounted old modal issues a request after its target or owner changed
- **THEN** request admission rejects it without changing the binding or invalidating newer work

#### Scenario: Owner teardown with modal open
- **WHEN** the forecast widget is removed or receives another owner while its modal is open
- **THEN** only its captured modal is released safely, no disposal-time ViewModel notification is required, and late physical forecasts cannot publish

#### Scenario: Rapid duplicate openings
- **WHEN** two valid opening requests occur in one scheduling interval, including before the first modal builder executes
- **THEN** only the first acquires admission, pushes one modal and requests each lazy forecast lane; the second performs no requests or navigation

#### Scenario: Target replacement during opening
- **WHEN** A changes to B while A's modal is being established or dismissed
- **THEN** A is revoked immediately, its builder cannot render forecasts and only its exact route is released when available; B cannot open another modal until A fully closes

#### Scenario: Captured modal is beneath another route
- **WHEN** old modal cancellation runs while a newer unrelated Navigator route is current
- **THEN** only the captured active modal is removed, preserving the newer and parent routes

#### Scenario: Dismissal and normal reopening
- **WHEN** the modal Future settles before its exit transition completes and another opening is attempted
- **THEN** admission remains occupied until full route closure, after which a valid fresh opening succeeds

#### Scenario: Owner replacement or unmount during pending modal Future
- **WHEN** the Button changes owner or unmounts before its modal Future settles
- **THEN** captured-route cancellation remains safe and completion accesses no unmounted State/context or invalid Navigator

#### Scenario: Obsolete modal callback after reopening
- **WHEN** a dismissal/completion callback from an old opening runs after a valid later opening is admitted
- **THEN** token identity and exact-route checks preserve the later opening's admission and route
