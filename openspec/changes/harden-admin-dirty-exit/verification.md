# Implementation verification

Verified on 2026-10-29 in timezone `Europe/Rome`.

## Scope and baseline

Implementation continues on `plan/harden-admin-dirty-exit` in PR #21, from planning commit `b028879273a7f1eb3afe01eca11a2c884880e6c5`. The original main baseline is `c7250f5db274c8b00af53cdd83846076918fd226`. Within PR #21, no backend, schema, dependency, generated model, tracked platform configuration or canonical specification changed. The primary checkout remains on main and clean.

After Android signing PR [#22](https://github.com/xmattjus/moliseis/pull/22) merged, the primary checkout was fast-forwarded to `5f51a39f59d73a5cc2ce68a6173871db39341874`. PR #21 rebased without conflicts from `ad0625e7949bdb6f5eb155c3bf873ffcc004637f` to `1359eb9e82bb646662bbdc00ca11abbe61602c9f`; range-diff and byte-for-byte patch comparison preserved all three original commits' changes. Push used an explicit remote-HEAD lease. The follow-up below changes only the discard hydration notification, its focused regression and verification records; PR #21 remains Draft.

## Automated verification

- Flutter 3.47.5 / Dart 3.13.4; go_router 18.0.2, material_ui 1.5.0, command_it 9.5.2.
- Focused Admin/Public/domain/dialog run: **1,314 passed**. Subsequent final routing and restoration run: **111 passed**, including new obsolete-callback regressions.
- Pre-rebase implementation autonomous suite: **3,780 passed, 4 existing skips**, across **180 test files**. File selection follows `.github/workflows/pull-request.yml`, explicitly excluding `test/integration/`; `TZ=Europe/Rome`, `flutter test --no-pub --reporter expanded`.
- Post-rebase source including the discard-controller correction: **3,781 passed, 4 existing skips**, across **180 test files**, using the same autonomous-suite selection and Rome timezone. `flutter analyze --no-pub`: **No issues found**.
- Analyzer before implementation and after original implementation changes: **No issues found** using `flutter analyze --no-pub`.
- `openspec validate harden-admin-dirty-exit --strict` and diff whitespace checks pass. Documentation links, task retention, path hygiene and protected-file scope are checked manually because this checkout has no dedicated documentation-audit command.
- The new worktree needed the ignored ObjectBox 5.3.2 test runtime. The existing primary-checkout binary was version-checked and copied into the ignored local runtime location; no tracked dependency/configuration changed.

Regression coverage includes reviewed A superseded before serialized entry (no write), B typed during an admitted A write (P/E=A, C=B dirty, no exit), C:=E with P different, recovery obligations and receipts/intents preserved, single-flight invocation ownership, invalid session hints refused before field effects, different-ID and query transitions, terminal Progress-only/full-stack navigation, auth revocation, authorized moderation, platform Back/Escape and responsive/focus/semantics checks. Shared dialog tests cover every requested width, both themes, default/2.0 text scaling and narrow landscape.

## Independent review and fixes

Independent adversarial review identified and verified corrections for terminal Progress full-stack removal, invalid resume hints mutating source work before refusal, and obsolete Back callbacks borrowing a replacement activation. Focused tests additionally caught notification during Navigator rebuild, unavailable pushed-page/source identity, and restoration-time route-state lookup. Source identity now comes from the router builder and actual page handles; stale callback regressions were executed RED then GREEN. Final static review has no outstanding material finding. Runtime results are the execution evidence above, not inferred from the review.

## Native verification

All runtime smoke uses an explicitly local fake-auth/fake-repository fixture with the production router, widgets and application theme. It never invokes the production Supabase bootstrap and does not establish real backend authorization or native storage durability. Temporary drivers, service metadata, screenshots and logs are excluded from the repository.

| Platform | Actually verified | Remaining native acceptance |
| --- | --- | --- |
| iOS Simulator: iPhone 17 Pro, iOS 26.5; Xcode 26.6 | Pre-rebase implementation source `flutter build ios --simulator --debug --no-codesign` passed. Earlier local fixture launched; programmatic clean exit, dirty dialog, Cancel, local checkpoint exit and discard to E passed with zero exit-driven remote writes/uploads. | **NOT VERIFIED:** real edge gestures, physical AppBar taps, complete Progress interaction and iOS auth-revocation smoke. Progress reached the editor URI with newer dirty fields, but its rendering-readiness assertion timed out; this is not counted as a passed native scenario. UI automation was not reliable enough to establish gestures. |
| macOS 26.5.2 | Existing locked CocoaPods setup generated the missing workspace without tracked changes. Debug fixture build/process startup and six programmatic checks passed: clean exit, dirty dialog, Cancel, checkpoint exit, discard with zero remote work, and simulated auth revocation removing private UI. | **NOT VERIFIED:** foreground/OS keyboard interaction. Flutter reported `Failed to foreground app; open returned 1`; background runtime and widget-tree assertions still completed. |
| Android: existing Pixel 10 Pro AVD, Android 17 / API 37, arm64 | After PR #22, the rebased local fixture compiled and launched without release-signing properties. Corrected Dart source was hot-restarted. Programmatic native-runtime checks passed: clean New/Edit exit, dirty dialog, Cancel, local Save and Exit, effective-baseline Discard and Exit, obsolete Back callback after target replacement, Flutter `handlePopRoute` dispatch and simulated auth revocation. Exit scenarios made zero fake Create/Update/association/deletion/moderation/upload calls. | **NOT VERIFIED:** OS system Back, actual predictive edge-gesture start/cancel/commit, physical AppBar/dialog taps and native storage durability. The available UI-control surface could not expose the emulator window. Automated Flutter Back tests and native-runtime synthetic dispatch do not establish these native inputs. |

The iOS runtime smoke predates the original implementation's final callback/restoration guards; the pre-rebase iOS source was rebuilt successfully. The macOS fixture smoke used the pre-rebase implementation source. Neither platform was rerun for the discard-hydration follow-up.

### Android follow-up and discovered defect

A raw Navigator route covering the editor immediately after successful Discard caused the exit policy to refuse removal. Native-runtime inspection reproduced session C restored to E while the retained name controller still showed discarded text; the next edit reintroduced that text. The minimal correction increments the existing hydration revision after successful, still-owned discard, before notifying. A deterministic production-router widget regression failed on the stale name controller before the fix, then passed for both name/city controllers and subsequent typing. All 47 tests in the affected routing file pass. The same retained-name scenario passed in the corrected Android runtime with zero checkpoint or remote-mutation/upload calls. Independent follow-up review found no material defect.

Programmatic Android Progress checks used an explicitly admitted, Completer-controlled fake Update and matching fake readback: running Progress blocked Flutter Back dispatch, and completed/conflict terminal return removed only Progress while retaining newer dirty session fields without a second Update or parent dirty-exit dialog. The completed case performed exactly one intentional fake Update and no other mutation/upload. Initial temporary-driver attempts edited before Save capture or returned stale fake readback; they failed their completed-Save assertions and are not counted as completed-Save passes. The controlled rerun passed. These observations concern programmatic runtime/model behavior, not physical input or native persistence.

The first follow-up widget-test attempt failed because the local disk was full; it is not counted as behavioral RED. Only newly generated signing-worktree build outputs were removed to recover space, then the genuine controller-mismatch RED and GREEN runs were executed. Temporary fixture extensions, drivers, logs and runtime evidence remain outside tracked files.

## Remaining acceptance

**Task 5.3 remains unchecked: native acceptance NOT VERIFIED.** The available automated work is complete (21/22 tasks); partial native smoke does not establish release readiness. PR #21 was not merged; no canonical-spec sync or archive was performed. No architectural scope deviation was required.
