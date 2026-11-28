# Canonical App Routing Delta

## ADDED Requirements

### Requirement: One global Admin Workspace entry
The application SHALL expose `/admin` as its single supported global Admin entry. Settings SHALL push that entry using ordinary app navigation. Login, Dashboard, Editor, and Save Progress SHALL be reachable only as presentations within the entry. Private destinations SHALL have no global URLs, legacy aliases, compatibility redirects or interpretation of old route parameters.

#### Scenario: Settings starts a workspace visit
- **WHEN** a user selects Admin from Settings
- **THEN** the existing Settings remains the predecessor of one Workspace entry regardless of the user's auth state
- **AND** internal navigation and auth state changes never append or replace global Admin destinations

#### Scenario: Old or unsupported staff destination
- **WHEN** an old Admin Login, New/Edit or Progress path is requested
- **THEN** ordinary unknown-destination handling applies
- **AND** a session, target or attempt value in a URL cannot open an internal presentation or admit work

### Requirement: Admin presentation is isolated from public navigation
Admin authority changes SHALL be contained within the Workspace. The application SHALL preserve the four public branches, supported public routes and restoration, and the existing application-level Sync gate. Inactive or covered private presentations SHALL relinquish Back participation for other routes.

#### Scenario: Back from the Workspace
- **WHEN** the user leaves from the Workspace landing with a valid predecessor
- **THEN** Back reveals the actual predecessor with its retained state
- **AND** with no predecessor, explicit Back follows the Home fallback and system Back retains normal platform/router root behavior

#### Scenario: Authority changes under a cover
- **WHEN** another presentation owns Back and Admin authority changes
- **THEN** the former private presentation is retired without rewriting public history
- **AND** Back goes to the currently entitled presentation without changing an inactive public branch

#### Scenario: Mandatory application Sync
- **WHEN** initial or fatal Sync takes precedence
- **THEN** ordinary Sync handling, fatal retry and validated return apply
- **AND** if the Workspace is removed, return can open only a fresh Workspace or the normal safe destination, without reviving old private state
- **AND** ordinary background Sync gains no authority to interrupt workflow or discard edits

### Requirement: Restart recovers work through a fresh Admin presentation
The application SHALL begin at normal Home or restore only the ordinary Workspace entry under fresh authority. It SHALL omit the private stack, Editor, Progress, modals, exit decisions and authority from presentation restoration. Existing durable Admin data shall be recovered only through its account-qualified recovery paths.

#### Scenario: Process restarts after editing or Save
- **WHEN** the app starts in a new process after private UI was open
- **THEN** Home or a safe Workspace entry appears, and verified Admin authority opens a fresh Dashboard
- **AND** no previous private navigation or Save attempt is restored or restarted

#### Scenario: Process remains alive
- **WHEN** the app returns from background with its Workspace present and authority continuous
- **THEN** the existing authorized presentation remains available subject to ordinary app lifecycle behavior
