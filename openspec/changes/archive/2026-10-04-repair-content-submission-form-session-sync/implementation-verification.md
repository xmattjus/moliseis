## Execution baseline

- Starting HEAD: `68638d6278a952f8662d919ddb860866cd3f2d0f`.
- Preserved preexisting changes: shared submission fields, color-scheme extension, pubspec/lock, and the user's Task 2.5 revision allowing a pre-fix green RED 3.
- Flutter 3.47.5 / Dart 3.13.4; the actual local dependency resolution included `material_ui 1.5.0` and `go_router 18.0.2`. Public lifecycle source is unchanged since the planning baseline.
- The working tree already contained independent dependency updates in `pubspec.yaml` and `pubspec.lock` when implementation started from `68638d6`. All apply baseline, RED and post-fix tests, including the full suite and analyzer, ran against this intentionally updated local resolution. This is the authoritative execution baseline, not a discrepancy with the committed manifest. Those dependency updates were not introduced by `repair-content-submission-form-session-sync`, were preserved, and are not required by the fix. `material_ui 1.5.0` is the runtime implementation whose `TextFormField.reset()` appears in the RED stacks below.
- Five-suite execution baseline: 226 tests passed. Analyzer: 177 diagnostics (173 info, 4 warnings, zero errors), exit 1. Logs `/tmp/form_session_apply_baseline_tests.log` and `/tmp/form_session_apply_baseline_analyze.log`.
- Recording harness alone: all 24 existing production-route tests passed (`/tmp/form_session_harness.log`). The local delegating ViewModel is explicitly authorized by the approved design/user request; it does not replace dirty comparison, retirement, submission or route policy.

## Pre-fix gates — production unchanged

### RED 1 — mandatory gate satisfied

Executed the real screen with `buildAppRouter`, remote acknowledgement gate and local clear gate. Before remote acknowledgement there is one submitted identity; while clear is pending submit remains running and normal success is absent. After successful local retirement, the first notification contains a different identity with exact canonical fresh state and `hasUnsavedChanges == false`. Subsequent notification stacks prove:

```text
_ContentSubmissionScreenState._handleSessionRetired callback (screen:84/85)
FormState.reset (Flutter form.dart:333)
_TextFormFieldState.reset (material_ui text_form_field.dart:450)
setCity / setName / setUserEmail / setUserName
ContentSubmissionViewModel._emit
```

The canonical equality assertion fails before navigation: city/name/email/author become empty strings, current snapshot diverges from the checkpoint and dirty becomes true. No framework exception, provider failure, timeout or test-generated mutation caused the failure. Exact command: `flutter test --no-pub test/routing/content_submission_route_test.dart --plain-name 'RED 1 retirement stays canonical beneath real progress'`; exit 1, one intended failure. Log `/tmp/form_session_red1.log`.

### RED 2 — specific Bug B path proven

Pending load is consumed once while the real screen is mounted with constructor identity A and only loading UI. Completion adopts persisted B, first emits exact clean B, then city/name nulls become empty strings through the same reset/setter stacks. The mixed recovery companion preserves populated city but changes absent name to empty string. Thus Bug B is **PROVEN for late persisted-session adoption through this reset path**; other reported empty-form causes are not automatically closed. Log `/tmp/form_session_red_verified.log`.

### RED 3 and Home

Recovered valid draft is initialized before mounting, and both Form states/contact controllers are present. Both Back and Nuovo-suggerimento regression cases fail before navigation: recovered city/name and original email/author are replayed into the retired fresh session (contact lengths 20 and 15). The independent Home case reaches the actual `Salvare le modifiche?` dialog. No production changes were present for these runs. Logs `/tmp/form_session_red_remaining.log` and `/tmp/form_session_red_verified.log`.

Same-session control separately passed before the fix. Its initial UI assertion needed the existing AppBar scrolled into view after text focus; no dirty or domain assertion was weakened. Log `/tmp/form_session_same_session_prefix.log`.

### Runtime source correction

The production imports use `material_ui`'s TextFormField, not Flutter's identically named class. The resolved `material_ui-1.5.0/lib/src/text_form_field.dart` has the same `late final _initialValue`, initState capture and reset/onChanged implementation inspected in the Flutter SDK. The runtime stack above is the authoritative invoked source. This corrects an evidence attribution in planning; it changes neither the root cause nor the approved two-Form replacement design.

## Post-fix verification

- Production diff: only `lib/ui/content_submission/widgets/content_submission_screen.dart` (12 additions / 18 deletions). Both Form keys change synchronously on a new identity; epoch and post-frame reset are gone. No ViewModel/router/progress/repository/backend/dependency change belongs to this repair.
- Added seven production-router widget tests: RED 1, empty late recovery, mixed late recovery, successful Home, recovered-contact Back, recovered-contact Nuovo suggerimento, and same-session input/checkpoint. Corrected three stale domain empty-string assertions in existing screen tests while retaining visually empty text expectations.
- Route + screen suites after fix: 68 tests passed (`/tmp/form_session_first_green.log`).
- Required eight focused suites: **259 passed**, exit 0 (`/tmp/form_session_focused.log`). Existing Android system/predictive and iOS clean/dirty/boundary regressions pass in this run, as do all-day, description, assets and restoration suites.
- Full `flutter test --no-pub`: **1779 passed, 3 skipped, zero failures**, exit 0 (`/tmp/form_session_full_tests.log`).
- Targeted `flutter analyze --no-pub` on the three changed Dart files: **No issues found**, exit 0 (`/tmp/form_session_target_analyze.log`).
- Full `flutter analyze --no-pub`: **177 diagnostics**, 173 info / 4 warnings / zero errors, exit 1 (`/tmp/form_session_final_analyze.log`). Diagnostic comparison ignoring shifted line numbers: **zero added, zero removed** versus the execution baseline. No unrelated lint cleanup was performed.
- `dart format --output=none --set-exit-if-changed` on touched Dart files: exit 0, zero changes.
- `git diff --check`: passed. Strict OpenSpec validation: passed.
- Independent adversarial review: no material findings.
- SHA-256 comparison against the execution-start bytes confirms the four preexisting application/dependency files were preserved exactly. Task 2.5's preexisting user revision remains intact; only task completion markers were updated around it. All other initial user work remains preserved.

## Device smoke and readiness

**Device smoke PASS — user reported.**

Manual checks for Tasks 5.1 and 5.2 were performed on a Pixel 10 Pro Android emulator running Android 17 Google APIs using a debug build. The user performed and reported these checks; the agent did not independently execute them.

The checks covered:
- untouched fresh form exit;
- successful submission → Home without an erroneous save-draft prompt;
- successful submission → Nuovo suggerimento / Back with a fresh clean form.

This is feature-level manual smoke evidence, not store-release readiness. Release/store validation remains outside the scope of this repair. The optional persisted-empty device condition was not separately reported; its deterministic automated regression evidence remains recorded above.

The earlier agent device enumeration found only macOS/Chrome and did not constitute a smoke test (`/tmp/form_session_devices.json`). The subsequent user report supersedes the previous manual-verification unavailability.

**Completion:** all 23 tasks are complete, including user-reported manual smoke checks. Bug A is fixed with causality proven before production edits. Bug B's late persisted-adoption path is proven and covered; broader empty-form reports are not assumed to have one cause. The implementation, regression tests and OpenSpec delta at `eecab1a97404d166b7d32c8c945a6dbe94469869` have been approved by adversarial review. No further production issue emerged; canonical sync and archive were completed on 2026-10-04. Strict pre-sync validation passed; all 11 canonical specs passed validation after sync. The one added requirement and all seven scenarios match the delta, with existing canonical text preserved.
