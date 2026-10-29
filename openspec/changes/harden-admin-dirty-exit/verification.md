# Implementation verification

Verified on 2026-10-29 in timezone `Europe/Rome`.

## Scope and baseline

Implementation continues on `plan/harden-admin-dirty-exit` in PR #21, from planning commit `b028879273a7f1eb3afe01eca11a2c884880e6c5`. The original main baseline is `c7250f5db274c8b00af53cdd83846076918fd226`. No backend, schema, dependency, generated model, tracked platform configuration or canonical specification changed. The primary checkout remains on main and clean.

## Automated verification

- Flutter 3.47.5 / Dart 3.13.4; go_router 18.0.2, material_ui 1.5.0, command_it 9.5.2.
- Focused Admin/Public/domain/dialog run: **1,314 passed**. Subsequent final routing and restoration run: **111 passed**, including new obsolete-callback regressions.
- Exact final implementation autonomous suite: **3,780 passed, 4 existing skips**, across **180 test files**. File selection follows `.github/workflows/pull-request.yml`, explicitly excluding `test/integration/`; `TZ=Europe/Rome`, `flutter test --no-pub --reporter expanded`.
- Analyzer before implementation and after final changes: **No issues found** using `flutter analyze --no-pub`.
- `openspec validate harden-admin-dirty-exit --strict` and diff whitespace checks pass. Documentation links, task retention, path hygiene and protected-file scope are checked manually because this checkout has no dedicated documentation-audit command.
- The new worktree needed the ignored ObjectBox 5.3.2 test runtime. The existing primary-checkout binary was version-checked and copied into the ignored local runtime location; no tracked dependency/configuration changed.

Regression coverage includes reviewed A superseded before serialized entry (no write), B typed during an admitted A write (P/E=A, C=B dirty, no exit), C:=E with P different, recovery obligations and receipts/intents preserved, single-flight invocation ownership, invalid session hints refused before field effects, different-ID and query transitions, terminal Progress-only/full-stack navigation, auth revocation, authorized moderation, platform Back/Escape and responsive/focus/semantics checks. Shared dialog tests cover every requested width, both themes, default/2.0 text scaling and narrow landscape.

## Independent review and fixes

Independent adversarial review identified and verified corrections for terminal Progress full-stack removal, invalid resume hints mutating source work before refusal, and obsolete Back callbacks borrowing a replacement activation. Focused tests additionally caught notification during Navigator rebuild, unavailable pushed-page/source identity, and restoration-time route-state lookup. Source identity now comes from the router builder and actual page handles; stale callback regressions were executed RED then GREEN. Final static review has no outstanding material finding. Runtime results are the execution evidence above, not inferred from the review.

## Native verification

All runtime smoke uses an explicitly local fake-auth/fake-repository fixture with the production router, widgets and application theme. It never invokes the production Supabase bootstrap and does not establish real backend authorization or native storage durability. Temporary drivers, service metadata, screenshots and logs are excluded from the repository.

| Platform | Actually verified | Remaining native acceptance |
| --- | --- | --- |
| iOS Simulator: iPhone 17 Pro, iOS 26.5; Xcode 26.6 | Exact final source `flutter build ios --simulator --debug --no-codesign` passed. Earlier local fixture launched; programmatic clean exit, dirty dialog, Cancel, local checkpoint exit and discard to E passed with zero exit-driven remote writes/uploads. | **NOT VERIFIED:** real edge gestures, physical AppBar taps, complete Progress interaction and iOS auth-revocation smoke. Progress reached the editor URI with newer dirty fields, but its rendering-readiness assertion timed out; this is not counted as a passed native scenario. UI automation was not reliable enough to establish gestures. |
| macOS 26.5.2 | Existing locked CocoaPods setup generated the missing workspace without tracked changes. Debug fixture build/process startup and six programmatic checks passed: clean exit, dirty dialog, Cancel, checkpoint exit, discard with zero remote work, and simulated auth revocation removing private UI. | **NOT VERIFIED:** foreground/OS keyboard interaction. Flutter reported `Failed to foreground app; open returned 1`; background runtime and widget-tree assertions still completed. |
| Android: existing Pixel 10 Pro AVD, Android 17 / API 37, arm64 | Emulator booted; Android Back and predictive Back paths pass automated Flutter tests. | **NOT VERIFIED:** native app startup/system/predictive Back. Existing `android/app/build.gradle.kts:41` requires absent release-signing properties and aborts debug assembly before Dart compilation with a null-to-String cast. No signing values or configuration were invented or changed. |

The iOS runtime smoke predates the final callback/restoration guards; exact final iOS source was rebuilt successfully. The macOS fixture smoke used the final source.

## Remaining acceptance

**Task 5.3 remains unchecked: native acceptance NOT VERIFIED.** The available automated work is complete (21/22 tasks); partial native smoke does not establish release readiness. No merge, canonical-spec sync or archive was performed. No architectural scope deviation was required.
