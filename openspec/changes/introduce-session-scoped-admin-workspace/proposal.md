# Proposal

## Why

Admin authority can end while GoRouter still retains a private page, an accepted push or its callbacks. The current topology has allowed a formerly authorized Dashboard to expose cached moderation data and admit new work after authority changed, making this a release blocker.

## What Changes

- Keep one root GoRouter, the four public branches and the application Sync gate. Settings opens the single `/admin` entry. It shows a safe auth state or a fresh Dashboard in a private Navigator owned by the current interval of continuous Admin authority.
- Invalidate private admission and publication synchronously when the auth owner observes authority end. Retire the private Navigator, Editor, Progress, modals, focus and feedback as a unit. Keep physical settlement and durable recovery with their existing owners.
- Use local navigation for Editor and local fullscreen state for admitted Save Progress. Preserve voluntary dirty exit, moderation authority, explicit Retry and Dashboard refresh through the supported local flow.
- **BREAKING** Retire global Admin Login, New/Edit and Save Progress locations and the former route-bound Dashboard contract. The same `/admin` path becomes the workspace entry. Internal destinations have no global links, URL compatibility or private presentation restoration. Recover account-owned data through a fresh authorized Dashboard and Editor.
- Extract authority, admission and lifecycle protections selectively from [PR #53](https://github.com/xmattjus/moliseis/pull/53). Implement the Workspace independently of that branch and of router upgrade work.

## Capabilities

### New Capabilities

None. Existing capabilities own these contracts.

### Modified Capabilities

- `canonical-app-routing` defines the single Admin entry, isolation from public history and safe restart.
- `explicit-back-navigation` applies ordinary predecessor and fallback behavior at the Workspace landing and retires global Admin diagnostic cases.
- `command-execution-concurrency` defines continuous Admin authority, guarded admission and publication, and current Editor effects.
- `admin-submission-editor` moves the Editor, Progress, exit and Dashboard return contracts into the Workspace.
- `admin-draft-persistence` expresses exact target/session matching at explicit recovery.
- `editor-picker-restoration` makes interrupted selection recovery independent of private navigation and retains exact picker provenance.

## Impact

Routing, Settings, Admin auth, Dashboard, Editor, local dialogs and feedback, and their integration tests change. Existing draft, staged asset, server replay, picker and backend enforcement boundaries continue to apply. Implementation work includes adding the permanent navigation ownership principle to `AGENTS.md`.

## Non-goals

Public navigation redesign, Admin deep linking, legacy URL migration, mixed history repair, general-purpose routing or operation orchestration, and dependency upgrades are outside this change.

## Release gate

Integrated application behavior, Android and iOS physical checks including real process restart, and controlled runtime server authorization are required before public release. Existing independent gates, including public NAV-01, also apply. Planning approval, merge readiness, OpenSpec completion and release readiness are distinct.
