## ADDED Requirements

### Requirement: Category bootstrap is valid before first rendering

A Category destination SHALL expose its validated initial selection before the first screen build. Initial loading SHALL NOT depend on an asynchronous filter update or notify during widget construction. Invalid slugs SHALL retain existing error routing. Rebuilding an unchanged retained owner SHALL NOT reseed filters or reload content.

#### Scenario: Single category first frame
- **WHEN** a valid single-category URI creates its owner with retrieval still pending
- **THEN** the first frame has that nonempty selection and renders safely without accessing an empty first element

#### Scenario: All categories first frame
- **WHEN** the canonical all-categories URI creates its owner
- **THEN** all supported categories are selected before rendering and the all-content retrieval path starts once

#### Scenario: Invalid category
- **WHEN** a slug is invalid, including a retired numeric slug
- **THEN** existing route error behavior is preserved and no Category content retrieval starts

#### Scenario: Retained route and replacement owner
- **WHEN** the same route rebuilds with the same owner, or a new owner is created for that route
- **THEN** the retained owner keeps its current state without another bootstrap while a replacement independently initializes from the validated URI

#### Scenario: Canonical restoration
- **WHEN** a supported canonical Category route is reconstructed after restoration
- **THEN** its new owner seeds the URI selection before its first rendering and preserves branch ancestry without claiming restoration of unsaved in-memory filter edits

### Requirement: Category filters share one latest-intent retrieval boundary

Changing Category categories or content types SHALL synchronously establish the desired selection and revoke prior retrieval publication authority. Retrieval SHALL use an immutable snapshot of both filters. Unchanged selection SHALL be a no-op; explicit refresh SHALL admit a fresh intent. Neither filter SHALL lose a change because another retrieval is pending. Previously exposed confirmed selections SHALL retain independent snapshot values after later changes.

#### Scenario: Category A then B
- **WHEN** B is selected while A retrieval remains pending
- **THEN** B can start without waiting for A and A cannot change B content, failure or loading state

#### Scenario: Category A then B then A
- **WHEN** category selection returns to A after admitting B
- **THEN** the final A is a new authoritative intent and the original A cannot publish even though its filter values match again

#### Scenario: Types and categories change together
- **WHEN** categories and types change while retrieval is pending, including in the same synchronous turn
- **THEN** the final intent contains both latest selections and no visible collection mixes data from different filter snapshots

#### Scenario: Unchanged selection and refresh
- **WHEN** an equal selection is submitted during or after retrieval, or refresh is explicitly requested
- **THEN** equal selection starts no new retrieval while explicit refresh admits a new intent even for equal filter values

### Requirement: Category publishes complete collections atomically

Category SHALL assemble selected places and events privately and publish only a complete successful authoritative result. The first application failure SHALL terminate that retrieval without publishing its partial collection. A changed filter SHALL clear prior content immediately; same-filter refresh SHALL retain the last complete collection internally on failure. Success with zero results SHALL commit an empty collection.

#### Scenario: Places succeed while events are pending
- **WHEN** place retrieval succeeds and selected event retrieval is still pending
- **THEN** the candidate places remain private and no partial collection is published

#### Scenario: First selected query fails
- **WHEN** the first selected retrieval returns an application failure
- **THEN** its Exception remains the load failure and no subsequent selected query starts

#### Scenario: Second selected query fails
- **WHEN** places succeed but selected event retrieval returns an application failure
- **THEN** no candidate places are committed and the error is distinct from successful empty content

#### Scenario: Successful empty result and retry
- **WHEN** all selected queries succeed empty, or a retry succeeds after failure
- **THEN** empty success replaces prior data with an empty collection and a successful retry atomically replaces it with the complete new collection

#### Scenario: Filter changes during private partial retrieval
- **WHEN** filters change after one query succeeded and another remains pending
- **THEN** the old private collection cannot appear under the new filters and only the new intent can publish

### Requirement: Category presentation follows the current load outcome

Category SHALL distinguish neutral/loading, nonempty/empty success and terminal failure, with retry independent of sort completion. Shared selectors SHALL preserve drafts for equal confirmed-set values and update changed fields from independent snapshots, retiring stale modal drafts. Empty drafts SHALL show explicit labels and normalize only on current modal close. Owner replacement SHALL detach observations and discard old callbacks.

#### Scenario: Loading and sort complete independently
- **WHEN** sorting completes while Category retrieval remains pending
- **THEN** the loading surface remains until the current load has a terminal outcome

#### Scenario: Failure and retained content
- **WHEN** same-filter refresh fails while an earlier complete collection remains stored
- **THEN** the failure/retry surface is displayed rather than representing retained data as new load success

#### Scenario: Empty success
- **WHEN** the authoritative load succeeds with no matching content
- **THEN** an explicit empty state is shown rather than an indefinite skeleton or a failure

#### Scenario: Modal outlives owner
- **WHEN** a selection modal is pending with a nonempty or empty draft and its Category owner is replaced or removed, including replacement with equal confirmed selections
- **THEN** its completion cannot normalize or publish to either the old owner or the replacement and the screen observes the current owner only

#### Scenario: Equal confirmed categories preserve editing
- **WHEN** a category modal has unconfirmed checkbox edits and its same-owner parent rebuilds with new wrappers containing equal confirmed categories
- **THEN** draft edits and State are preserved, no callback occurs during editing and normal close publishes the resulting selection exactly once

#### Scenario: Equal confirmed types preserve editing
- **WHEN** a type modal has unconfirmed checkbox edits and its same-owner parent rebuilds with equal confirmed type values, including different iteration order
- **THEN** the type draft is preserved without a callback until normal close, regardless of wrapper identity

#### Scenario: Changed confirmed selection updates its field
- **WHEN** a confirmed category or type set changes by value under the same owner
- **THEN** the widget updates that field from the new independent snapshot without emitting a callback or resetting the other field’s draft, and displayed labels and selection on reopening reflect the new values

#### Scenario: Confirmed changes supersede the open draft session
- **WHEN** the widget observes its open modal’s confirmed set change by value under the same owner, including A to B and back to A delivered by separate rebuilds
- **THEN** subsequent checkbox edits affect only the captured old draft, its close performs no normalization or callback, the new confirmed selection remains intact and reopening uses it; changing only the other field does not supersede the current modal, and coalesced updates observed only as equal A to A preserve the draft instead

#### Scenario: Empty drafts remain safe through rebuild
- **WHEN** all category or type checkboxes are deselected and the parent rebuilds with equal confirmed values while the modal remains open
- **THEN** the draft remains empty, labels show Nessuna categoria or Nessun tipo without accessing an empty first element, no callback or all-options reset occurs and editing can continue

#### Scenario: Empty confirmation normalizes once
- **WHEN** a still-mounted category or type modal whose draft session is still current closes normally with an empty draft
- **THEN** all supported options of that field are restored before exactly one callback and no persistent empty-filter semantics are introduced

#### Scenario: Shared Map selector preserves its existing contract
- **WHEN** the same shared selector is used by Map and its parent rebuilds during editing, including with an empty draft
- **THEN** semantic draft retention and safe labels also apply, with the existing callback signature, publication only on normal close and empty-to-all confirmation behavior preserved

### Requirement: Category publication uses the current session ordering

Category SHALL order names ascending and modification dates descending according to the current session preference. A successful retrieval SHALL apply the current preference at commit time. A later retrieval completion SHALL NOT restore an ordering captured before a newer accepted sort action. Sorting SHALL NOT require refetching content or changing filter authority.

#### Scenario: Sort during query
- **WHEN** the accepted sort changes while a query is pending and that query subsequently succeeds
- **THEN** the complete published collection uses the newly selected ordering

#### Scenario: Loaded collection is sorted
- **WHEN** an accepted sort action changes the preference with content already committed
- **THEN** current content and menu selection update optimistically before persistence completes without a new content query

### Requirement: Category sort persistence remains single-flight and truthful

Sort writes SHALL admit at most one action per lane; duplicate pending requests SHALL NOT queue or supersede. Repeating the current sort SHALL perform no write. An accepted change SHALL preserve the optimistic session ordering on persistence failure and expose the original write Result. Unexpected throws SHALL remain runtime failures. Existing repository persistence contracts SHALL remain unchanged.

#### Scenario: Persistence fails
- **WHEN** the sort repository returns an application failure
- **THEN** the sort action exposes that failure while the session order remains selected and the repository cache retains its established failure behavior

#### Scenario: Same or concurrent sort
- **WHEN** the selected sort is repeated, or another sort request arrives before the lane settles
- **THEN** no redundant write or queued request starts and the accepted action retains ownership

#### Scenario: Sort persistence throws
- **WHEN** the pending write throws a handled unexpected runtime failure
- **THEN** it remains a runtime failure with existing global reporting and does not fabricate successful persistence or change the current load outcome

### Requirement: Category disposal revokes presentation before private cleanup

Disposal SHALL immediately revoke Category commits, notifications, observations and new repository phases. Already-started reads or sort writes SHALL retain safe private settlement and existing unexpected-error reporting. Settled resources SHALL be released exactly once outside active notifier dispatch. Owner replacement SHALL NOT transfer old work publication authority to the new owner.

#### Scenario: Dispose before action entry or between query stages
- **WHEN** Category is disposed before a queued action enters or while its first query is pending
- **THEN** no not-yet-started repository phase begins and no late content or notification is published

#### Scenario: Late outcomes after navigation
- **WHEN** already-started work returns success, application failure or handled runtime failure after navigation disposes the owner
- **THEN** no old-owner presentation mutation or notification occurs, original handled runtime errors remain reportable once and cleanup avoids secondary disposed-notifier failures

#### Scenario: Reentrant disposal
- **WHEN** an owner is disposed from its own notification or an execution terminal observer
- **THEN** public authority is revoked immediately and owner/execution notifiers are released safely after dispatch and required settlement without duplicate disposal

#### Scenario: Assertion and nonterminating future
- **WHEN** pending work fails an assertion or remains physically pending indefinitely
- **THEN** assertions retain the existing fail-loud development path with settled cleanup, while physically pending work may retain private resources without regaining publication authority
