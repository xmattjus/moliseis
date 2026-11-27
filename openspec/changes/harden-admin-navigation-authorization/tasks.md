# Tasks

## 1. Baseline and isolated GoRouter upgrade

- [x] 1.1 Verify the implementation branch and remote main against the investigation SHA. Preserve the opt-in inputs outside committed history. Reproduce the relevant original Admin characterizations and navigation controls on locked 18.0.2. Record route/owner identities, invocation counts and any pre-existing failures as described in [the test plan](test-plan.md#dependency-comparison).
- [x] 1.2 Reconfirm latest stable on pub.dev and inspect its published source and SDK constraints. Update the GoRouter constraint and resolve the lockfile using the normal Flutter pub workflow in a dependency-only commit. Compare all direct/transitive lock entries and package config against baseline, including both UI packages and SDK dependencies. Add no overrides, unrelated upgrades or SDK migration. Escalate unsuccessful compatible resolution without silently choosing a lower release.
- [x] 1.3 Repeat the original probes and affected public and Admin navigation suites on the dependency-only commit. Exercise GeoMap NAV-01 with its existing expectations using a scratch unskip if needed. Keep any permanent enabling or annotation with verification updates and preserve the comparison evidence. Keep production application authorization fixes out of this commit.
- [x] 1.4 Record the checkpoint classification for F1–F4 and related regressions as unchanged, resolved upstream, behaviorally changed or new. Retain an application history correction only for demonstrated remaining gaps. Reconcile any resulting scope or verification changes in the OpenSpec artifacts before application edits. Retain the independent Dashboard and pending activation requirements. Stop affected work and escalate a material incompatibility, unrelated upstream regression or out-of-scope requirement.

## 2. Authority and feature ownership

- [x] 2.1 Extend the existing Admin auth owner to commit continuity before notification. Preserve live session correlation and the same-account token refresh contract. Verify A1 across queued observations, stream failure/recovery and rapid replacement.
- [x] 2.2 Bind a Dashboard Provider owner and its rendering, menus, recovery and callbacks to admission-time authority. Retire it independently of disposal and give B fresh state and reads. Verify H2 and D1 using exact owners, presentation and repository/navigation counters. Use a single app messenger and verify selective retirement of both visible and queued Dashboard feedback.
- [x] 2.3 Guard Dashboard reservation, asynchronous repository entry, notification reentrancy, publication and every follow-up stage. Retain private settlement through original terminal or assertion handling. Verify D2–D3, zero stale dispatch before entry, no intermediate refresh continuation, exact release, and unchanged authorized lane ordering.
- [x] 2.4 Qualify the existing Editor route and pending activation, including session-hint lookup and Save Progress, with the original authority before awaiting. Preserve existing generations, local checkpoint/asset ownership and picker contracts. Verify E1–E2 with controlled lookup and settlement order, old callbacks and account-specific recovery.

## 3. Router reconciliation and regression coverage

- [x] 3.1 Apply the smallest remaining Admin history correction established by 1.4. Preserve public history, login from Settings, explicit logout, Sync precedence and validated returns. Retire obsolete dialogs and pending enter/exit/navigation intent without letting them veto authority-driven departure. Verify H1–H4 against actual installed pages and Back, including revoked/restored state and the exact uninstalled-cover sequence. Preserve exact public form and Progress matches through a covering reconciliation. Preserve the public exit decision when pending and the ordinary exit policy when the form actually leaves. If the upgrade satisfies a case, capture the expected regression without an application workaround.
- [x] 3.2 Convert applicable opt-in characterizations into normal regression tests with desired assertions alongside their owning fixes. Verify traceability to A1, H1–H4, D1–D3 and E1–E2, merge duplicated cases around shared failure boundaries and preserve existing tests' assertions. Cover the R1 and R2 review regressions in the existing routing and feedback suites. Keep raw probes outside permanent history.

## 4. Combined verification and review

- [x] 4.1 Run all affected routing and feature suites and then the full Flutter suite and applicable analyzer checks on the combined implementation. Confirm public compatibility and distinguish any pre-existing failures from changes. Run strict OpenSpec validation and review the final diff for scope, lifecycle, reproducibility and dependency attribution.
- [x] 4.2 Execute the disposable local Supabase runtime matrix in the [test plan](test-plan.md#disposable-supabase-runtime-gate). Record actual responses/effects, local limitations and open release items without credentials. Escalate material server authorization defects separately and keep the release gate open.
- [x] 4.3 Prepare one PR with independently reviewable planning, dependency upgrade, application remediation/regressions, and applicable documentation/verification updates. Keep the dependency-only commit free of application changes, including authorization work that masks the before/after comparison. Use the repo's Conventional Commit/PR title skill and PR template. Confirm outstanding device checks and the release decision are recorded in the linked navigation record.

## Workflow follow-up

- The owner executes the [physical-device release gates](test-plan.md#owner-executed-physical-device-release-gates). Preserve incomplete gates in the durable navigation record and record completion only from observed results.
- Use the same PR for the full change. Merge, canonical sync, archive and release follow their separately authorized project workflow.
