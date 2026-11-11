# Proposal

## Why

The Admin Dashboard has no explicit Back control, exposes recovery solely because a draft repository is configured, and provides no visible toolbar-refresh progress or transient failure feedback when submissions are retained. Harden these interactions while preserving the existing Settings stack, account-owned recovery, independent read lanes and private safe settlement.

## What Changes

- Add an accessible dashboard Back action that pops the existing route when possible and falls back to Home for direct entry. Verify the real GoRouter stack and pushed-login replacement without redesigning routing.
- Replace the permanent AppBar resume action with one persistent, actionable, explicitly dismissible custom Snackbar, eligible only after a successful current-account navigation-intent lookup.
- Extend the existing Snackbar helper minimally with native persistence/close support and cancellable ownership. Prevent queued stale recovery and allow ordinary feedback to temporarily displace recovery, then revalidate and restore an undismissed candidate without clearing unrelated messages. Automatic eligibility failures remain silent; explicit recovery failures use existing generic error feedback.
- Give admitted manual dashboard refreshes an execution-correlated outcome while preserving existing `Future<void>` APIs, command reporting and safe settlement.
- Use one centered `EmptyView.loading` presentation with the exact visible text `Caricamento in corso` and one accessible secondary action labeled `Annulla` for admitted toolbar and pull refreshes. Keep the Dashboard AppBar visible while temporarily hiding the entire filter bar and list, empty or error content. `Annulla` dismisses only that waiting presentation and immediately restores retained content, selection controls and relevant scroll state, even while the admitted read remains pending. Its accessibility description must clarify that the update may continue. Preserve physical execution, independent read lanes and the pull callback's execution-correlated safe settlement; dismissed presentation callbacks cannot publish stale feedback. Preserve the existing custom error Snackbar for authorized failures, with no success notification or global sync dependency.
- Add focused navigation, helper, recovery and read-lifecycle regressions without weakening existing protection tests.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: Explicit dashboard Back semantics, preserved route ancestry, admitted refresh outcome exposure and owner-qualified manual refresh feedback.
- `editor-picker-restoration`: Contextual dashboard recovery presentation and notification lifetime, retaining original account/session and navigation nonce contracts.

## Impact

Expected production surfaces are `admin_dashboard_screen.dart`, `admin_submissions_view_model.dart` and `custom_snack_bar.dart`; reuse `CustomBackButton`, `EmptyView.loading`, existing command executions and draft lookup. Router/Login changes are conditional on a regression demonstrating a defect in the current stack behavior. Existing callers retain ordinary Snackbar defaults and refresh APIs. Tests extend the actual router harnesses, dashboard command harness, draft fixtures and custom Snackbar coverage. No packages, backend changes, persistence schema changes or authentication architecture changes are proposed.

Editor visuals, Public Content Submission, Location Picker/GeoMap refactors, automatic checkpoint redesign and synchronization workflow changes are excluded. Detailed verified evidence, tradeoffs and acceptance coverage are in `design.md` and the delta specifications.

The final corrective planning and implementation are authorized within existing PR #40 on `docs/unify-admin-dashboard-refresh-presentation` in worktree `moliseis-admin-dashboard-refresh-plan`; no separate implementation PR is required.
