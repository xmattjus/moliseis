## ADDED Requirements

### Requirement: Calendar selection immediately owns day retrieval

Every accepted calendar selection SHALL immediately update the highlighted Rome civil day and revoke prior day presentation authority. Pending SHALL show loading without an old terminal outcome. Current success SHALL show events or empty state; domain and handled runtime failure SHALL show generic error and explicit retry of the current day. Equal values after intervening selections SHALL be new intents. Annual-cache hits SHALL avoid queries; failed fallback SHALL remain retryable.

#### Scenario: Rapid day selection returns to the first value
- **WHEN** A is selected, then B, then A while earlier queries remain pending
- **THEN** the final A is selected immediately and only its retrieval can publish data, success, failure or loading state

#### Scenario: Queries complete out of order
- **WHEN** the newest day completes before an older day
- **THEN** old success or application failure cannot replace the newest outcome and an old handled runtime failure is reported once without current presentation changes

#### Scenario: Loaded day is repeated
- **WHEN** the currently selected successfully loaded day is selected again without an annual dataset change
- **THEN** no additional query or pending state starts and the previously committed day collection and terminal success remain intact, including fallback events absent from the annual dataset and successful empty fallback retrieval

#### Scenario: Failed day is repeated
- **WHEN** fallback retrieval fails and the same day is explicitly selected again
- **THEN** a fresh attempt is admitted without treating failure as a populated cache entry

#### Scenario: New day is visible before retrieval entry
- **WHEN** A completed and B is selected before B retrieval starts
- **THEN** selection and calendar highlight already show B, the modal shows pending and A content or failure is never presented as B, including before the new public snapshot arrives

#### Scenario: Current day fails terminally
- **WHEN** the current day returns an application error or handled runtime failure
- **THEN** the skeleton ends with generic error and Riprova, old content is not presented as current, domain error keeps its Exception without global reporting and runtime failure keeps original unexpected object and stack reported once

#### Scenario: Retry uses the day selected at activation
- **WHEN** Riprova is activated after a noncacheable day failure
- **THEN** a new intent uses the day selected at that moment rather than a previously captured date, can query again and renders pending then events or empty success without annual reload, owner recreation or automatic retry

#### Scenario: Annual rebase finishes pending day presentation
- **WHEN** annual success supersedes a pending day fallback with current annual-derived events or an empty collection
- **THEN** the modal settles with current grid or empty state without awaiting the obsolete query or starting an additional query

### Requirement: Annual and day calendar results share dataset authority

Annual loading SHALL bootstrap once per owner and remain single-flight. Annual success SHALL replace the annual dataset and re-evaluate the current day, revoking fallback publication against the previous dataset. Annual failure SHALL retain previous data. Successful annual-derived empty days SHALL remain eligible for explicit fallback retry.

#### Scenario: Annual data replaces pending fallback
- **WHEN** annual success supplies the selected day while an older fallback is pending
- **THEN** the new annual dataset revision rebuilds the selected-day cache and presentation, invalidates cached fallback data from the prior revision and prevents older fallback completions from overwriting it or retaining current loading

#### Scenario: Annual success has no selected-day events
- **WHEN** annual success replaces the dataset with no events on the selected day
- **THEN** the selected-day presentation can settle empty, old fallback publication is revoked and a subsequent explicit same-day selection may query again

#### Scenario: Annual reload fails
- **WHEN** an annual reload returns an application failure
- **THEN** the prior annual collection, day cache validity and day selection remain intact and explicit annual retry remains available

### Requirement: Post detail follows its route owner and terminal outcome

A Post destination SHALL load only the detail type selected by its validated id/type URI. A retained owner SHALL not rebootstrap on an unrelated rebuild. Pending or failed detail SHALL not read uninitialized content or bind weather. A handled terminal failure SHALL end loading and display an error surface. Replacement owners SHALL not inherit old completion authority.

#### Scenario: Deferred bootstrap
- **WHEN** a valid event or place route is created and detail action entry is deferred
- **THEN** the first frame renders safely while exactly the selected detail lookup is admitted

#### Scenario: Detail failure
- **WHEN** current detail returns an application error or a handled runtime failure
- **THEN** loading ends with explicit failure presentation, weather remains unbound and no uninitialized content is read; runtime failure retains global reporting

#### Scenario: Owner replacement
- **WHEN** route A is replaced by a different id or type B and A finishes late
- **THEN** B has its own detail, weather and nearby state and A cannot affect B or start later work on its disposed owner

#### Scenario: Detail recovery
- **WHEN** a new accepted detail attempt succeeds after failure
- **THEN** current content becomes available and weather binds once to the current owner, content identity and coordinates

### Requirement: Post nearby preserves ordered partial outcomes

Nearby detail retrieval SHALL remain single-flight and query events before places. An events application error SHALL not prevent the places query. Successful sides SHALL remain available in event/place order, with the first application error as the aggregate failure. Existing invalid-coordinate, deferred scheduling and retry presentation behavior SHALL be preserved.

#### Scenario: Events fail and places succeed
- **WHEN** events return an application failure and places return content
- **THEN** the aggregate remains the original events failure and the owner retains the successful places without reporting fabricated aggregate success

#### Scenario: Places fail after events succeed
- **WHEN** events succeed and places fail
- **THEN** the owner retains the events and exposes the places failure; the Post presentation retains its established failure projection and absence of a retry button

#### Scenario: Stale scheduled nearby request
- **WHEN** coordinates are invalid or the owner/content changes before the deferred callback
- **THEN** no query starts for invalid or previous content and only the current valid load identity can be requested

#### Scenario: Disposal between nearby queries
- **WHEN** the owner is disposed while events are pending
- **THEN** late events cannot publish and no places query begins

### Requirement: Sync admission controls navigation before action entry

Automatic due sync SHALL be admitted before the first frame. Sync SHALL remain single-flight; concurrent requests SHALL neither queue nor supersede. Force SHALL bypass the schedule; non-forced work SHALL recheck whether sync is due. Navigation SHALL use immediate admission state and receive a settlement refresh after that state becomes non-running.

#### Scenario: Automatic bootstrap
- **WHEN** the application starts with sync due and action entry has not yet occurred
- **THEN** navigation already treats sync as running and enters the sync destination without briefly exposing an idle destination

#### Scenario: Forced request during active sync
- **WHEN** another forced or scheduled request arrives during admitted sync
- **THEN** only the admitted synchronization runs and the rejected request causes no queued second pass or false success feedback

#### Scenario: Non-forced operation is no longer due
- **WHEN** a non-forced admitted action enters after the schedule has become satisfied
- **THEN** it settles successfully without invoking synchronization

### Requirement: Sync failures separate availability from error kind

Sync SHALL preserve application failures as Results and handled runtime failures as unexpected outcomes with original global reporting once. A current failure SHALL be fatal for navigation exactly when no successful-sync timestamp is available. Fatal state SHALL describe the current attempt and reset on a new admission or success. Assertion policy SHALL remain fail-loud.

#### Scenario: First synchronization fails
- **WHEN** an accepted sync fails with an application or handled runtime failure and no successful-sync timestamp exists
- **THEN** the sync destination remains available for explicit retry, without converting runtime failure into a domain Result

#### Scenario: Cached synchronization fails
- **WHEN** accepted sync fails with an existing successful-sync timestamp
- **THEN** failure is nonfatal, valid cached data remains available and normal return navigation is permitted

#### Scenario: Fatal retry recovers
- **WHEN** a fatal attempt is retried and succeeds
- **THEN** fatal state clears and navigation can return to the retained valid destination

### Requirement: Sync return navigation and feedback belong to the current attempt

Sync SHALL retain the internal URI and query and return to a validated destination after nonfatal settlement; unsafe return locations SHALL fall back to Home. Current nonfatal failure feedback SHALL remain visible after normal return, at most once per observed accepted attempt. Not-yet-authorized stale feedback SHALL be suppressed. Consumers SHALL observe owner replacement, detach old observations and reconcile the current outcome without rerunning sync.

#### Scenario: Detail URI is restored
- **WHEN** manual sync interrupts a valid detail or search destination and settles successfully or nonfatally
- **THEN** the retained internal URI and supported query parameters are restored under existing branch and back-navigation rules

#### Scenario: Invalid return location
- **WHEN** an idle or nonfatally settled sync destination has an unsafe or invalid return location
- **THEN** navigation returns to Home without recursive sync redirection

#### Scenario: Current nonfatal feedback survives normal return
- **WHEN** sync terminates with a domain or handled runtime nonfatal failure while its screen is the current observer and navigation normally returns to the valid preserved URI
- **THEN** one error snackbar is visible after return, normal removal of the sync screen does not revoke already-authorized feedback and runtime reporting retains the original object and stack once

#### Scenario: Retry or owner change precedes feedback authorization
- **WHEN** feedback remains pending and a new accepted retry, owner replacement or unrelated unmount supersedes the observation before authorization
- **THEN** the old callback produces no feedback or other stale action and performs no context or owner access after unmount

#### Scenario: Different attempts share one exception object
- **WHEN** two accepted attempts observed by the current consumer fail with the same Exception instance
- **THEN** each attempt can authorize one feedback, repeated rebuilds do not duplicate it and a rejected busy request creates no new attempt or feedback

#### Scenario: Retained screen receives another owner
- **WHEN** the provider replaces A with B while retaining the sync screen state
- **THEN** the screen observes the replacement, detaches A and attaches B once, ignores late A notifications and reconciles already-terminal B without starting new work; this local lifecycle guarantee does not replace the sync owner already captured by an existing router

#### Scenario: Application router and screen use the same sync owner
- **WHEN** the supported application lifecycle builds its router and provides sync state to its screen
- **THEN** both use the same owner for bootstrap, redirect, fatal retry and completion; a new session with another owner uses a coherently recreated application and router lifecycle rather than implicitly rebinding an existing router

#### Scenario: Unchanged provider and fatal failure
- **WHEN** dependencies rebuild with the same owner or its current failure is fatal
- **THEN** unchanged identity does not reset feedback deduplication or duplicate observations, and fatal failure retains its error and retry surface without nonfatal snackbar

### Requirement: Content owners revoke presentation before private settlement cleanup

Event, Post and Sync disposal SHALL immediately revoke commits, notifications and new owner-controlled action phases. Already-started sync SHALL retain its domain protocol. Settled commands SHALL release resources once outside notifier dispatch, retaining late handled-runtime reporting. Physically pending work SHALL not regain presentation authority.

#### Scenario: Dispose before deferred entry
- **WHEN** the owner is disposed after admission but before action entry
- **THEN** no repository or sync invocation begins

#### Scenario: Late Result or runtime throw
- **WHEN** started work settles after owner disposal with success, application failure or a handled runtime failure
- **THEN** no presentation mutation occurs, runtime reporting retains the original object and stack once, and private release causes no disposed-notifier failure

#### Scenario: Disposal during notifier dispatch
- **WHEN** a terminal, value or owner listener disposes the owner reentrantly, including while logically idle
- **THEN** revocation is immediate and physical notifier cleanup occurs safely outside dispatch exactly once

#### Scenario: Started synchronization outlives owner
- **WHEN** the owner is disposed after synchronization has started
- **THEN** its domain protocol can settle without owner UI notifications, cancellation claims or ViewModel intervention in persistence phases
