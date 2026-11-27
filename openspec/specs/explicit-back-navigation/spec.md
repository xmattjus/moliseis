# Explicit Back Navigation Specification

## Purpose

Define ordinary app-owned Back departures and consistent native presentation
while preserving feature and platform navigation ownership. The ordinary
pop and result guarantees apply to synchronous departures. Protected
asynchronous exits retain their existing policy and completion path.

## Requirements

### Requirement: Ordinary Back acts only for its originating route

An ordinary Back activation SHALL verify that its displayed Route still owns
the requested departure in the committed navigation stack. A permitted
synchronous pop SHALL remove only that originating Route and reveal its actual
predecessor.
A denied activation SHALL make no secondary navigation request.

#### Scenario: An inactive or covered route still exists

- **WHEN** a source belongs to an inactive branch, the committed branch changes
  before the old branch rebuilds, or a root page or popup covers the source
- **THEN** Back from the ineligible source leaves the stacks unchanged, even
  if the old Route remains locally current

#### Scenario: An existing predecessor is protected by a departure veto

- **WHEN** the originating route has a predecessor but cannot be popped
- **THEN** Back leaves that route and predecessor in place and does not request
  Explore

#### Scenario: Back follows the current navigation ancestry

- **WHEN** ordinary Back pops a pushed route or a route with a declarative
  predecessor
- **THEN** it reveals the exact predecessor and preserves its retained state,
  including the Search query where applicable

#### Scenario: Refresh follows a synchronous explicit pop

- **WHEN** immediate router refresh follows a successful synchronous ordinary pop
- **THEN** the removed route stays removed and its actual predecessor remains

#### Scenario: A pushed entry is being reconciled after refresh

- **WHEN** a supported refresh replaces the live push result before the
  displayed Route uses the new entry
- **THEN** ordinary Back leaves both entries alone
- **AND** a later activation can pop the reconciled source and complete only its
  live result

### Requirement: Eligible standalone Back requests canonical Explore

An eligible ordinary source without a predecessor SHALL request canonical
Explore root, subject to existing router admission and redirects. A source
already at canonical Explore root SHALL make no request.

#### Scenario: The visible Back control is tapped on standalone Login

- **WHEN** Login is the only page and the user activates its eligible Back
- **THEN** the app reaches canonical Explore root without an empty navigation
  configuration or a navigation assertion

#### Scenario: Login was pushed above Settings

- **WHEN** eligible Back is activated on Login pushed from Settings
- **THEN** it returns to the exact retained Settings Route and state

#### Scenario: A standalone ordinary source has a retained Explore detail

- **WHEN** the source makes an eligible fallback request
- **THEN** it reaches Explore root even if Explore retains a deeper page,
  subject to the normal router admission and redirects

#### Scenario: Explore is already displayed at its root

- **WHEN** the ordinary decision is evaluated at canonical Explore root with
  no predecessor
- **THEN** it leaves Explore and its navigation state in place

### Requirement: Error companion controls use the same departure policy

Leading and text Back controls on the same error SHALL use the same
departure policy. Matched ordinary errors SHALL follow their owning routes.
Unmatched errors SHALL require the current displayed root error source.

#### Scenario: An ordinary unmatched error is shown

- **WHEN** the eligible error is shown as an imperative Page above a
  predecessor or as a standalone first root Page
- **THEN** either control returns to the actual predecessor or requests
  Explore according to the ordinary policy
- **AND** a covered or obsolete error activation makes no request

#### Scenario: The existing malformed Admin diagnostic is shown

- **WHEN** the user activates either Back control on the diagnostic
- **THEN** it qualifies the source before dispatch and makes no request if
  the diagnostic is covered, obsolete or otherwise ineligible
- **AND** an eligible activation requests only a departure to the actual
  predecessor through the existing protected exit policy, with no Explore
  fallback
- **AND** a single ordinary diagnostic departure preserves an underlying
  editor and its retained draft

#### Scenario: A legitimate declarative replacement precedes cover installation

- **WHEN** Settings has committed above a pushed diagnostic but the diagnostic
  is still installed, and an authenticated Dashboard stack without an active
  dirty editor is declaratively replaced by Explore
- **THEN** the existing exit policy permits the replacement without retry
- **AND** the replacement leaves both push results pending

### Requirement: Shared Back has native presentation and interaction

Shared Back SHALL preserve the themed platform glyph, RTL direction, icon
customization, localized tooltip and accessibility semantics, existing
background and spacing options, and leading visibility. Where supported
mobile constraints permit, its effective interaction target SHALL be at
least 48 × 48 logical pixels.

#### Scenario: Theme, locale or layout changes

- **WHEN** an existing host renders Back under a different platform, locale,
  direction or constraint
- **THEN** the native control adapts and preserves the configured options and
  reachable interaction geometry
- **AND** its tooltip reads “Indietro” in Italian and “Back” in English

#### Scenario: A mobile slot accommodates the target

- **WHEN** a Back host can fit the 48 × 48 target
- **THEN** its semantic bounds and hit-tested edges cover that target, the
  visible face is centered, and adjacent controls remain independent

### Requirement: Feature and platform departures retain ownership

A supplied feature callback SHALL fully replace the ordinary decision and
remain callable without GoRouter where supported. Existing feature policies,
visibility and results, Gallery presentation lifecycle and platform Back
ownership SHALL be preserved.

#### Scenario: A feature uses an override

- **WHEN** a protected or local feature activates its custom Back
- **THEN** only that callback runs and its existing departure policy applies

#### Scenario: Dashboard evaluates its terminal ordinary decision

- **WHEN** Dashboard's feature authority allows evaluation but source
  qualification denies departure
- **THEN** no dispatch occurs and its existing one-action authority is
  available to a later eligible activation

#### Scenario: Gallery closes through ordinary Back

- **WHEN** eligible ordinary Back closes Gallery and reveals its predecessor
- **THEN** Gallery's existing presentation owner decides reservation release
  and autoplay based on the physical lifecycle

#### Scenario: System Back or a native gesture runs

- **WHEN** the platform requests or cancels Back
- **THEN** existing eligibility and behavior apply without the ordinary
  explicit Explore fallback
