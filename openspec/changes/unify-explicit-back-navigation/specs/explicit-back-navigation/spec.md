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
- **AND** the popped entry's outstanding result is completed once

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

### Requirement: Explicit Back keeps request admission separate from departure

A permitted dispatch starts a request. The application SHALL recognize
departure only when the originating route has actually left the committed
presentation. A refusal, failure or obsolete activation SHALL issue no
secondary navigation. An outstanding ordinary request SHALL admit at most
one explicit departure from its originating presentation.

#### Scenario: A fallback is refused with route information still pointing at it

- **WHEN** the committed source survives a refused fallback and the requested
  URI still appears in route information
- **THEN** a fresh eligible activation can retry
- **AND** a refresh does not replay the refused explicit fallback

#### Scenario: An external request is pending and then refused

- **WHEN** an unresolved external navigation is evaluating departure from
  the current standard Back presentation
- **THEN** an activation cannot dispatch against the source while it is pending
- **AND** a fresh activation can act on the same source once the request has
  settled there, even if the requested URI is still reported by the provider

#### Scenario: A newer navigation supersedes a pending explicit fallback

- **WHEN** a later navigation supersedes an explicit fallback before it commits
- **THEN** the old request cannot issue another navigation or restore its
  source's authority over the later presentation

#### Scenario: Repeat and independent activations

- **WHEN** the same control or its companion requests a departure repeatedly
  while the same departure is pending
- **THEN** at most one departure is admitted
- **AND** a separate activation from the current successor remains eligible

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
  again and has no unresolved departure

#### Scenario: The source was removed or rebound

- **WHEN** an old callback is invoked after its route is removed or after its
  page has presented a different semantic identity under the same page key
- **THEN** it has no effect, including after a new visit returns to the old value
- **AND** an activation from the newly bound current presentation can act

### Requirement: Companion Back actions share the source's departure policy

When an error surface shows both icon and text Back, both SHALL use one
source and departure policy. The malformed Admin Editor error SHALL leave
through its protected route's exit policy and actual predecessor.

#### Scenario: Ordinary route error or unavailable Gallery

- **WHEN** an available leading or text Back is activated on an ordinary error
- **THEN** both controls apply the same predecessor, veto and fallback rules

#### Scenario: A protected malformed Admin detail receives repeated Back

- **WHEN** its two controls are activated while one departure is pending
- **THEN** the exit policy decides whether that exact page is removed
- **AND** an allowed return completes its result once, preserves any underlying
  editor state, and remains removed after refresh
- **AND** a refused or superseded request initiates no Explore fallback

#### Scenario: System Back reaches a stale malformed Admin page

- **WHEN** system Back reaches the previously popped malformed page after its
  removal committed and before the Navigator reconciles
- **THEN** the retired page cannot complete its result again or remove another
  route on its behalf

### Requirement: Back presentation follows the app's adaptive theme

Shared Back controls SHALL use the effective themed platform, directional
icon, customized icon where supplied and localized accessibility label. They
SHALL retain configured spacing and backgrounds and preserve target
reachability within the host's constraints.

#### Scenario: Theme and layout differ between hosts

- **WHEN** a Back control renders under another platform, locale, text
  direction, icon theme or constrained host
- **THEN** it presents the corresponding native appearance, semantics and
  tooltip with the configured layout and a target at least as reachable as
  before

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
