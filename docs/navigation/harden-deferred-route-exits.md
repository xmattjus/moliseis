# Harden deferred route exits

**Status — deferred pending a suitable upstream correction or another
demonstrably proportionate solution.** This record carries forward task 4.1,
task 4.3 and the “Diagnostic departures overlap” scenario from
[unify-explicit-back-navigation](../../openspec/changes/archive/2026-11-27-unify-explicit-back-navigation/proposal.md).

## Dependency behavior and reproduction

Use the production router with an authenticated Admin, initially settled,
and an imperative push of the malformed diagnostic (`/admin/submissions/abc`).
Keep the original Route, installed Page, match and result completer available
for identity assertions. Use microtask turns without pumping a frame to separate
router commits from Navigator reconciliation.

- **F01 — duplicate imperative completion.** While the diagnostic is above
  a pushed dirty editor, send two Back requests before its deferred `onExit`
  commits. Exercise leading → companion, companion → leading, leading → leading,
  leading → system, system → leading and system → system. GoRouter 18.0.2 can
  schedule two approvals for the same installed match. A repeat completion
  throws `Bad state: Future already completed`. Expect a single diagnostic
  completion with null, one removal, no exception, and the same underlying
  editor Route, State and dirty draft with its own result still pending.
- **S2 — navigation intervenes during approval.** Dispatch explicit Back from
  the current diagnostic, then push a cover before flushing microtasks.
  Observe a commit containing the original diagnostic and the cover while the
  diagnostic is still installed and its result pending. An earlier approval
  can complete the diagnostic in the newer configuration and truncate the
  stack past it. Expect the cover and diagnostic to remain committed with
  both results pending, and a later eligible single departure to work. Check
  refresh, replacement and auth-driven navigation during pending approval.
  In the sign-out probe without a cover, the pending departure committed
  Dashboard before the Login redirect and completed the diagnostic result.
- **S3 — cover already committed at physical dispatch.** Settle the new editor,
  push and settle the diagnostic, then push an Admin Dashboard cover. Drain
  microtasks without pumping a frame. Verify the committed top is the cover,
  the original diagnostic match is still in the committed list, both results
  are pending, and the diagnostic is physically current with pop disposition
  `pop` and its original Page at the top of the Navigator. Without first
  requesting Back, send one system Back and drain microtasks. On main and
  after the rollback, the diagnostic completed and the committed stack lost
  both the diagnostic and cover. The cover result stayed pending. Expect
  identical committed configuration and pending results for both matches.
  After installing the cover, a deliberate cover departure may complete only
  its own result. The reconciled diagnostic must then be able to depart to the
  same retained editor.
- **S4 — replacement match already committed at physical dispatch.** Settle an
  editor under the pushed diagnostic. Refresh and drain microtasks without a
  frame. Verify the committed diagnostic has the same Page key but a different
  path-parameter map and completer. The original diagnostic remains current
  with its original Page and pop disposition `pop`. Send one system Back before
  reconciliation. On main and after the rollback, the obsolete result
  completed, while the exact live configuration and pending live result
  survived. Expect no configuration change and both results to remain pending.
  After reconciliation, the same physical Route has a new Page. A fresh
  qualified Back should complete only the live
  result and reveal the same editor Route.
- **Mixed Back — second request reaches the retained editor.** Start native
  Back on the diagnostic, then invoke explicit Back before the system request
  finishes its asynchronous eligibility check. If one path removes the
  diagnostic first, the other may fall through to the editor's exit policy.
  A clean retained editor can depart and complete its push. A dirty editor
  can surface an unsaved-changes prompt. Expect the editor to retain its
  Route, State, draft and pending result, with no editor prompt for requests
  initiated on the diagnostic. Verify a subsequent deliberate editor Back
  follows the existing policy.
- **F06 / S5 — legitimate declarative replacement.** On a settled Dashboard
  with no active dirty editor, push the diagnostic and commit a Settings cover
  without installing it. Verify the diagnostic's Page still occupies the
  physical top, Settings is the committed top, and both results are pending.
  Call `router.go(RoutePaths.home)` once. The removed application workaround
  mistook the legitimate stack replacement for a stale physical pop and
  left Settings committed. The restored callback permits a single nonempty
  Explore commit with both results pending and no exception. Keep that
  regression in the [Admin routing tests](../../test/routing/admin_route_test.dart).

GoRouter 18.0.2 schedules physical-pop approval using the match associated
with the installed Page and completes that captured match without rechecking
committed ownership. Both physical removal and legitimate declarative
replacement can evaluate the same diagnostic through `onExit`, with no
departure kind supplied to that callback.

The spike evaluated [Flutter Packages PR #12112](https://github.com/flutter/packages/pull/12112)
at `81aad02e92c2bbff1bad7ef50f37a6692855e625`. It prevented the duplicate
completion exception, while stale dispatch and mixed targeting remained
reproducible. This was an experiment. The application still resolves
GoRouter 18.0.2. Related upstream work includes
[Flutter #156809](https://github.com/flutter/flutter/issues/156809),
[Flutter #191280](https://github.com/flutter/flutter/issues/191280) and
[Flutter Packages PR #12500](https://github.com/flutter/packages/pull/12500).

## Conditions for resuming

Verify exact committed match ownership both when a physical pop dispatches
and when its approval is consumed. A candidate must prevent duplicate
completion, reject stale approval after intervening navigation, preserve
new covers and replacements, permit legitimate declarative replacement,
keep mixed Back on its originating target, and preserve protected editor
policy, chained pops and subsequent navigation. An upstream merge only
identifies a candidate for these checks. Legacy restoration and native
route reporting beyond the ordinary Back contract remain investigation
areas.
