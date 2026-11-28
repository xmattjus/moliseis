# Explicit Back Navigation Delta

## ADDED Requirements

### Requirement: Eligible standalone Back returns to canonical Explore

An eligible ordinary source without a predecessor SHALL request canonical
Explore root, subject to existing router admission and redirects. A source
already at canonical Explore root SHALL make no request.

#### Scenario: The visible Back control is tapped on a standalone Workspace landing

- **WHEN** the Admin Workspace landing is the only page and explicit Back is used
- **THEN** the app reaches canonical Explore root without an empty navigation
  configuration or a navigation assertion

#### Scenario: The Workspace was pushed above Settings

- **WHEN** eligible Back is activated on the Workspace landing, whether it shows Login or Dashboard
- **THEN** it returns to the exact retained Settings Route and state

#### Scenario: A standalone ordinary source has a retained Explore detail

- **WHEN** the source makes an eligible fallback request
- **THEN** it reaches Explore root even if Explore retains a deeper page,
  subject to the normal router admission and redirects

#### Scenario: Explore is already displayed at its root

- **WHEN** the ordinary decision is evaluated at canonical Explore root with
  no predecessor
- **THEN** it leaves Explore and its navigation state in place

### Requirement: Error companion controls share the ordinary departure policy

Leading and text Back controls on the same error SHALL use the same
departure policy. Matched ordinary errors SHALL follow their owning routes.
Unmatched errors SHALL require the current displayed root error source.

#### Scenario: An ordinary unmatched error is shown

- **WHEN** the eligible error is shown as an imperative Page above a
  predecessor or as a standalone first root Page
- **THEN** either control returns to the actual predecessor or requests
  Explore according to the ordinary policy
- **AND** a covered or obsolete error activation makes no request

## REMOVED Requirements

### Requirement: Eligible standalone Back requests canonical Explore

**Reason**: Admin Login no longer owns a standalone or pushed global page.

**Migration**: Use the Workspace landing for the same predecessor and Explore fallback guarantees.

### Requirement: Error companion controls use the same departure policy

**Reason**: The malformed global Admin diagnostic and its protected replacement path cease to exist.

**Migration**: Unknown Admin URLs use the ordinary unmatched error policy. Public Back and existing public route owners retain their ordinary guarantees.
