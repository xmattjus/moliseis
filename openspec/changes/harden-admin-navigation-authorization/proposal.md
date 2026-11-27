# Harden Admin navigation authorization

## Why

An Admin Dashboard retained beneath Login can return through Back and expose cached submission summaries, contributor names and ignored-source information after Admin access ends. Retained actions can also reach the repository, and switching directly between administrators transfers stale presentation and operation intent. These client-side defects block the next public release.

## What Changes

- Retire Admin history, presentation and operations when the app observes loss or replacement of the authority that admitted them. Preserve ordinary authorized navigation, public ancestry where possible, sync behavior and account-bound durable drafts.
- Give each newly authorized Dashboard fresh ownership and reads. Bind callbacks, repository dispatch, continuations and publication to the authority that admitted them while allowing already-started operations to settle safely.
- Upgrade GoRouter from 18.0.2 to the latest stable release on pub.dev, confirmed at planning as 18.1.4. Rerun baseline probes on the isolated dependency commit before choosing any application history correction.
- Deliver the plan, dependency upgrade, application remediation and verification in one PR with independently reviewable commits. Verify the local backend contract and track owner-executed Android and iOS release gates.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency` gains continuous Admin authority, obsolete history invalidation, and Dashboard admission, presentation and settlement requirements.
- `admin-submission-editor` extends authority-driven exit protection to pending activation and restored private context while preserving existing durable work.

## Impact

The change affects the existing auth owner, GoRouter integration, route-owned Dashboard and the Editor's authority binding. The dependency regression surface includes public navigation and restoration. Production backend contracts, server schema, deployments and editor workflows remain outside the implementation scope. The [navigation record](../../../docs/navigation/harden-admin-navigation-authorization.md) tracks release status.
