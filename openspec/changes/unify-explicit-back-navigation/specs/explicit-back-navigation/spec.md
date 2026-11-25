# Spec Delta

## Purpose

Define when app-owned explicit Back may return to the previous route or
Explore root, and how feature actions and platform Back retain their owners.

## ADDED Requirements

### Requirement: Standard explicit Back returns to the actual predecessor

A standard explicit Back SHALL evaluate its originating presentation and
Navigator at activation. When departure is permitted and a predecessor exists,
it SHALL remove only that originating route, preserving the actual predecessor
and its retained state.

#### Scenario: A page was pushed

- **WHEN** eligible Back is activated from a page pushed above an existing route
- **THEN** only the pushed page is removed and the same predecessor is revealed
- **AND** the popped live entry's result is completed once

#### Scenario: A deep link or restoration supplies a branch parent

- **WHEN** eligible Back is activated from a canonical Category, Post or Search
  Results reached by deep link or restoration
- **THEN** it returns one level through the owning branch and preserves the
  predecessor's canonical identity and query `q` where applicable

#### Scenario: Refresh follows a successful explicit pop before rendering

- **WHEN** the router refreshes after an ordinary explicit pop commits and before
  route information is reported
- **THEN** refresh uses the surviving navigation entry and does not reopen the
  page that Back removed

#### Scenario: Refresh changes the match before the Navigator rebuilds

- **WHEN** an activation arrives after a refresh committed a new match for
  a still-mounted page and before the Navigator uses that match
- **THEN** the activation leaves the stack and its results alone
- **AND** the current presentation can act after Navigator reconciliation

### Requirement: Standard explicit Back has a canonical Explore fallback

An eligible standard Back activation without a predecessor SHALL request
canonical Explore root subject to existing router admission and redirects.
An activation already at canonical Explore root without a predecessor SHALL
leave the current stack in place.

#### Scenario: Standalone source or retained Explore detail

- **WHEN** an eligible standalone source requests fallback and it is permitted
- **THEN** Explore opens at its root unless an existing redirect applies
- **AND** the fallback creates no history entry above the source it replaces

#### Scenario: Explore is already at its root

- **WHEN** the policy is invoked at canonical Explore root without a predecessor
- **THEN** it leaves that route, stack and state in place

### Requirement: An unsuccessful standard Back has no secondary action

An obsolete activation, route veto or refused navigation SHALL NOT cause a
secondary navigation. A fresh activation from a still-eligible presentation
SHALL remain possible. A request to go to Explore SHALL remain subject to
normal router admission and redirects.

#### Scenario: A predecessor exists but departure is vetoed

- **WHEN** an explicit Back is activated from a page with a predecessor and
  that page disallows the pop
- **THEN** it remains in place and Explore is never requested

#### Scenario: An independent navigation replaces the source

- **WHEN** another navigation has replaced the source of an explicit action
- **THEN** the obsolete callback makes no further navigation request
- **AND** an eligible control on the successor can act independently

### Requirement: Standard Back affects only its originating presentation

A standard Back callback SHALL require a live, current route, active owner
and matching displayed identity. Removal and replacement invalidate the old
binding. Equivalent rebuilds, refresh and temporary coverage SHALL preserve
the binding of a retained presentation.

#### Scenario: A retained page is temporarily covered or inactive

- **WHEN** a captured Back is invoked while its source is covered by a page
  or popup or is in an inactive branch
- **THEN** it changes neither presentation's stack
- **AND** the same retained presentation is eligible after it becomes current
  again

#### Scenario: The source was removed or rebound

- **WHEN** an old callback is invoked after its route is removed or after its
  page has presented a different semantic identity under the same page key
- **THEN** it has no effect, including after a new visit returns to the old value
- **AND** an activation from the newly bound current presentation can act

### Requirement: Companion Back actions share the source's departure policy

When an error surface shows both icon and text Back, both SHALL use one
source and departure policy.

#### Scenario: Ordinary route error or unavailable Gallery

- **WHEN** an available leading or text Back is activated on an ordinary error
- **THEN** both controls apply the same predecessor, veto and fallback rules

### Requirement: Malformed Admin errors return without leaving a retained editor

An authorized request for a malformed Admin submission identifier SHALL show
a diagnostic under Admin without activating an editor session. Both explicit
actions SHALL return only to the actual predecessor when eligible. The
editor's own exit decisions SHALL apply whenever navigation removes the
editor itself.

#### Scenario: Malformed link or named navigation

- **WHEN** an authorized request supplies an identifier rejected by the
  submission ID codec
- **THEN** the Admin error retains the original diagnostic URI and parameters
  without using a session hint to start an editor
- **AND** a direct entry has Dashboard as its predecessor
- **AND** valid editor, New and Save Progress destinations retain their behavior

#### Scenario: Concurrent Back requests target the dedicated Admin diagnostic

- **WHEN** leading, text or system Back requests overlap on the same live
  dedicated Admin diagnostic route
- **THEN** that page is removed once and its live imperative result completes
  once if it was pushed
- **AND** the exact predecessor is retained, including any dirty editor and
  its activation
- **AND** subsequent requests captured from the retired error leave the stack
  alone, with no Explore fallback

#### Scenario: The dedicated Admin diagnostic is explicitly popped before refresh

- **WHEN** explicit Back pops the live dedicated Admin diagnostic route and
  refresh follows before the next frame
- **THEN** the request retains its actual predecessor and the error stays removed

#### Scenario: A historical malformed imperative entry restores to the editor route

- **WHEN** restoration places a historical malformed imperative entry on the
  original editor route
- **THEN** it renders the defensive Admin diagnostic without activating an
  editor session
- **AND** explicit Back remains subject to the existing protected exit policy
  and returns only to the actual predecessor when permitted, with no Explore
  fallback
- **AND** the dedicated route's concurrent Back guarantee does not apply

#### Scenario: An independent declaration also leaves the editor

- **WHEN** a declaration replaces the error and an underlying editor
- **THEN** the editor's own policy decides whether it can leave
- **AND** declarative removal does not manufacture an imperative pop result
- **AND** an action retained by the retired error cannot override the new stack

### Requirement: Back presentation follows the app's adaptive theme

Shared Back controls SHALL use the effective themed platform, directional
icon, customized icon where supplied and localized accessibility label. They
SHALL retain caller-configured spacing and backgrounds. A default padded
mobile Back target SHALL be at least 48 × 48 logical pixels where host
constraints permit it, with native glyph and background presentation.

#### Scenario: Theme and layout differ between hosts

- **WHEN** a Back control renders under another platform, locale, text
  direction, icon theme or constrained host
- **THEN** it presents the corresponding native appearance, semantics and
  tooltip with the configured layout and a target at least as reachable as
  before
- **AND** the native tooltip is “Indietro” in Italian and “Back” in English

#### Scenario: A standard mobile leading slot is 56 logical pixels

- **WHEN** default Back is rendered in a 56 × 56 padded mobile leading slot
- **THEN** its native target is at least 48 × 48, including the interactive
  edges and accessibility bounds, and the visible face remains centered
- **AND** it does not overlap another control

### Requirement: Feature overrides and platform Back retain their own policies

A custom explicit Back callback SHALL fully replace the standard action.
Existing feature policies own their decisions, destinations and control
visibility. Platform Back and native gestures SHALL retain their behavior.

#### Scenario: Local or protected override is used

- **WHEN** an editor, submission, Search, GeoMap or picker uses its own action
- **THEN** only that action runs, including any pending-operation veto,
  checkpoint, cleanup or return result where applicable
- **AND** a custom action can run without an app router

#### Scenario: A screen intentionally offers no Back

- **WHEN** a shell root, Sync or a standalone submission form without a
  predecessor is displayed
- **THEN** the change adds no explicit departure control

#### Scenario: Platform Back is used

- **WHEN** system Back, Android predictive Back or native iOS Back is invoked
  or cancelled
- **THEN** existing effects and eligibility are preserved independently of
  explicit Back's Explore fallback
