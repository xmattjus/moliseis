# Tasks

## 1. Native control

- [x] 1.1 Adopt the native Material Back control. Verify themed Android/iOS/macOS appearance, RTL, icon customization, Italian and English labels, semantics, custom callback without GoRouter, background, padding and existing visibility. Measure actual edge hits, semantic bounds, adjacent controls and face centering in representative hosts, including constrained and desktop layouts.

## 2. Ordinary navigation and integration

- [x] 2.1 Implement the source-qualified pop, named Explore and no-op decision. Verify the actual predecessor and absence of secondary navigation on a veto or failed check. Exercise a root popup over a locally current branch, a branch change committed before rendering, and a retained source after coverage clears. Verify named Explore with a retained detail, Explore-root no-op, and synchronous GoRouter pop followed by immediate refresh.
- [x] 2.2 Connect Settings, Login, Category, Post and Search Results where ordinary Back applies. Use the actual app router and tap visible standalone Login Back, asserting Explore root, no empty commit and no navigation assertion. Cover the existing sign-out redirect to standalone Login. Use the Settings entry control and preserve its exact retained Route and state for Login popped before authentication, and preserve existing replacement to Dashboard after authentication. Verify canonical branch ancestry and retained Search query.
- [x] 2.3 Cover observed imperative refresh interleaving in Settings and Gallery. Exercise the actual control across commit and reconciliation. Assert no stale removal or result completion before reconciliation and correct live pop after it. Check that ordinary refresh or rebuild leaves an unchanged push usable. Keep Gallery presentation and restore ownership, and rerun its permanent lifecycle and routing regressions. Include Gallery Unavailable with its existing visibility and fallback.
- [x] 2.4 Give ordinary matched and unmatched error controls a shared departure. Verify both controls, actual pushed predecessor, standalone fallback, root coverage and existing diagnostic logging. Keep the malformed Admin diagnostic on its existing protected route with predecessor-only Back. Verify that closing it preserves any retained editor and existing exit policy.
- [x] 2.5 Delegate Dashboard's terminal decision after its feature checks. Verify both layouts, retained Settings and standalone Explore, and that failed preflight leaves its one-action authority available. Rerun focused editor, Save Progress, submission, Search and picker checks for unchanged feature-owned departures and results.

## 3. Compatibility and release gates

- [x] 3.1 Run focused routing, restoration and widget regressions, including keyboard and semantics activation, system Back and simulated predictive and native gesture cases. Keep NAV-01 open. Track physical gestures and the existing iOS VoiceOver Nearby Retry and Profile gates separately from simulated results. Validate OpenSpec and compare canonical diagnostics by identity against main.

## 4. Ordinary reconciliation and lifecycle

- [x] 4.2 Exercise consecutive committed refreshes with and without intervening Page reconciliation, immediate refresh after a synchronous pop, matched and unmatched error replacement, and stale callbacks during a transition and after disposal. Exercise framework gesture ownership, cancellation and completion. Verify test sensitivity by temporarily removing the relevant discriminants.
- [x] 4.4 Verify that both explicit diagnostic controls reject a committed but uninstalled cover and that explicit Back rejects an obsolete push after refresh. Verify a subsequent eligible single diagnostic departure. Remove the deferred-exit wrapper and verify legitimate declarative replacement during reconciliation.

Deferred work from 4.1 and 4.3 is tracked in
[Harden deferred route exits](../../../../docs/navigation/harden-deferred-route-exits.md).
[Admin navigation authorization](../../../../docs/navigation/harden-admin-navigation-authorization.md)
is a separate investigation.
