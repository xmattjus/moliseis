## 0. Preflight / ownership and acceptance gates

- [x] 0.1 Verify current branch/HEAD, diff/staged/untracked inventory, root/nested AGENTS.md, PR2 archive and other active OpenSpec ownership; preserve unrelated work and reconcile source drift before modifications.
- [x] 0.2 Confirm Flutter/Dart/OpenSpec versions, `pubspec.lock` Quill/very_good_analysis versions and current source locations. Re-run `flutter analyze --no-pub`, retain full output/exit/identity ledger. Reconcile historical 202 and the 20 targets; do not assume counts or positions if checkout differs.
- [x] 0.3 Map all 15 boolean declaration occurrences to implementation overrides, use cases, widgets, test fakes, handler assignments and tests with repository-wide references. Check Quill 11.6.0 resolved API behavior/default and examine existing regression coverage before implementation.

## 1. Completion ownership (`unawaited_return_in_try_block`)

- [x] 1.1 Change only the acknowledged finalization return inside `_submit` to `return await`; preserve guard, flag, try/finally and Command behavior (D2).
- [x] 1.2 Ensure existing tests exercise pending finalization, failure after remote acknowledgement, active-owner retention, immediate retry without duplicate remote submission, and pre-acknowledgement ownership release; add only deterministic tests for proven coverage gaps.

## 2. Gallery parsing (`avoid_catching_errors`)

- [x] 2.1 Replace the `on ArgumentError` path with explicit inclusive DateTime epoch-millisecond bound checks on both timestamp fields. Preserve typed payload checking and Media construction behavior (D3).
- [x] 2.2 Run gallery parser tests for both accepted bounds, just-outside values, extreme ints, malformed/random primitives, nullables, negative dimensions, and roundtrip. Extend only uncovered boundary cases.

## 3. Named booleans + callback compatibility (15 infos)

- [x] 3.1 Update both favourites repository contracts/implementations, use-case delegations, FavouriteViewModel public method and persistence calls to `{required bool save}`; update fake repository overrides/handlers and assigned closures, all callers/tests, preserving single-flight optimistic and rollback semantics.
- [x] 3.2 Update SettingsRepository contract/concrete/fake and SettingsViewModel's repository invocation to `{required bool enable}`; keep the private `_setCrashReporting(bool)` and existing legacy `Command1` untouched; verify failure rollback and Sentry flag behavior.
- [x] 3.3 Update admin/content submission `setEventEnabled({required bool enabled})` and content submission `setAcceptedTerms({required bool? value})` plus all UI/integration/test callers; preserve admin external-event restrictions and nullable terms state. At both `lib/ui/content_submission/widgets/content_submission_screen.dart` and `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart`, replace the direct event-mode setter tear-off with the positional closure prescribed in D4, retaining the existing ViewModel receiver. Acceptance: `ContentSubmissionFields.onEventChanged` remains `ValueChanged<bool>`; each UI callback invocation forwards the boolean unchanged and invokes the setter exactly once; event-mode semantics and underlying Flutter APIs remain unchanged, with no additional adapters/wrappers. Verify both call sites through the analyzer acceptance gate in 5.3 and the existing content/admin widget suites named in D9 and required by 5.2; add no redundant task or test solely for this adaptation.
- [x] 3.4 Update weather `iconForCode(int, {required bool isDay})` and all callers/tests; verify day/night overrides and unknown fallback unchanged.
- [x] 3.5 Replace both framework-shaped callback declarations with `ValueChanged<bool?>` (category checkbox) and `ValueChanged<bool>` (AppNetworkImage plus test helper), maintaining positional invocation and callback timing.
- [x] 3.6 Re-run call-site search and compiler/analyzer for missing named arguments or new lint occurrences. Check test fakes' recorded call inputs and success/error paths unchanged.

## 4. Quill experimental API (3 warnings)

- [x] 4.1 Verify from resolved `flutter_quill` source that the current false setting is still required and has no stable behavior-equivalent alternative. Do not silently accept default rich paste.
- [x] 4.2 Retain the exact false setting; if no stable alternative exists, add exactly one narrow `// ignore: experimental_member_use` immediately before its one-line use, together with a rationale. Confirm all three warnings disappear, with no file/global ignore and no dependency change.
- [x] 4.3 Run existing rich-text field tests; audit configuration preservation and document whether native external-rich-paste behavior can actually be asserted by current automated tests. Add a focused test only if meaningful and deterministic; record any optional device/manual verification as such.

## 5. Final validation and review

- [x] 5.1 Run `dart format` on explicitly touched Dart files only. Audit all code/test diffs and call-site propagation, accidental Command changes, imports, source API compatibility, generated/backend/config drift and preexisting-work ownership.
- [x] 5.2 Run all focused suites listed in D9 and additionally discovered impacted suites, with commands/exits/pass/fail/skip summaries. Run full `flutter test --no-pub --reporter json` on the final code; investigate failures and distinguish proven preexisting skips.
- [x] 5.3 Re-run `flutter analyze --no-pub` (capture actual exit). All four target rule counts must be zero and there must be zero new diagnostics; verify 182 out-of-scope info identities by rule, severity, message, file and diff-mapped position. The 182 total is only a projection for unchanged baseline; expected exit remains 1, analyzer not a required merge gate.
- [x] 5.4 Run `git diff --check` and `git diff --cached --check`; verify no unrelated files, dependency, CI, generated outputs, backend, root AGENTS.md or canonical specs changed. Report exceptions/blockers rather than silently broadening scope.
- [x] 5.5 Reconcile every baseline occurrence with final diff, tests and D1–D10. Validate with `openspec validate resolve-flutter-analyzer-diagnostics-pr3 --strict --no-interactive` and confirm specs skipped; obtain independent adversarial review and resolve in-scope findings.
- [x] 5.6 Produce a concise evidence-backed readiness report. Do not commit, push, create/merge a PR, sync specs or archive without separate authorization.


## Apply verification report — 2026-10-14

### Baseline, authorization and ownership

Local implementation was explicitly authorized after adversarial review and F1 remediation. The earlier planning-only statements remain historical; this report records actual apply results. No commit, push, PR, merge, spec sync or archive was authorized or performed.

- Initial and final branch: `codex/archive-resolve-flutter-analyzer-diagnostics-pr3`; HEAD `6ccc62635d033747159d37c718ad38d961de8376`, equal to local `main` and `origin/main`. No checkout or Git history/index mutation.
- Initial working tree: preexisting ` M AGENTS.md` and untracked PR3 directory; no staged changes and no production/test drift. Read root instructions, all four approved artifacts and OpenSpec context/config; no nested AGENTS.md found.
- Active `improve-admin-submission-editor-workflow` overlaps admin VM/screen/test paths, but there were no concurrent source edits. Its artifacts and the two completed active changes are preserved. PR1/PR2 archive conventions and acceptance were rechecked.
- Preflight snapshots included bytes/hashes of the 1067 tracked/non-ignored files, staged/unstaged inventories, original source/test/artifact contents and full analyzer output. Flutter 3.47.5 stable (framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`), Dart 3.13.4, OpenSpec 1.12.0; resolved Quill 11.6.0, very_good_analysis 11.0.0, command_it 9.5.2. Actual SDK cache metadata, Dart executable, lockfile and resolved package sources verified; no dependency update.
- Before `flutter analyze --no-pub`: exit 1, 202 diagnostics = 0 errors + 4 warnings + 198 info. All 20 target identities and positions matched the approved matrix; no material drift.

### Implemented changes and semantic audit

- D2: exactly one `return await` in the acknowledged `_submit` branch. Flag, captured identity, `acknowledged` guard, finally, ownership release, serialization, retry, disposal and legacy Command are unchanged. Existing deterministic Completer tests already prove running/identity retention, local-clear failure and repeated finalization-only retry without duplicate remote work, pre-acknowledgement failure release and concurrent clear/session retirement. No duplicate submit regression test added. The old return already adopted the finalization Future; this change is not claimed to repair early success or ownership release.
- D3: direct inclusive comparisons against ±8640000000000000 on both timestamp fields before construction; remove ArgumentError catch and update its explanatory comments. Bounds match the installed SDK core/VM/JS validation. Field typing, nullable casts, local DateTime construction, dimensions, URLs, ordering/index checks and public constructor stay unchanged. Extend the existing acceptance test to both createdAt and modifiedAt endpoints using its existing fixture; no new harness.
- D4/D6: named required save/enable/enabled/value/isDay propagated through owned contracts, ObjectBox implementations, use case, VMs, production callers, all test callers, fake overrides (including ControllableEventRepository), handler types/invocations and configured closures. Recorded IDs/booleans, Results, fallback expressions, persistence, optimistic updates, rollback and single-flight remain unchanged. Settings' private positional callback and Command1.execute(bool) are unchanged.
- F1: only the two prescribed positional screen closures forward enabled unchanged exactly once to the named setter. ContentSubmissionFields.onEventChanged remains ValueChanged<bool>; setter bodies and admin external-event restriction are unchanged. No additional adapter or Flutter API change.
- D5: category ValueChanged<bool?> and image/helper ValueChanged<bool>? retain positional invocation, nullability and frameBuilder logic. Weather mapping tables and bodies are unchanged; all three callers retain the original code/day expressions.
- D7: retain the one-line enableExternalRichPaste:false configuration and add one immediately preceding experimental_member_use ignore with rationale. Locked Quill source defaults external rich paste to true and exposes no stable equivalent; removing the setting would change behavior. All three warnings disappear without unnecessary_ignore. No clipboard implementation/package change.

### Files changed

34 Dart files, with no new or removed repository files. Production changes are the constrained async/parser/Quill edits and boolean/callback propagation; test/support edits are signature propagation plus the one extended gallery boundary case. Exact changed Dart paths:

```text
lib/data/repositories/event_repository_impl.dart
lib/data/repositories/place_repository_impl.dart
lib/data/repositories/settings_repository_impl.dart
lib/domain/repositories/event_repository.dart
lib/domain/repositories/place_repository.dart
lib/domain/repositories/settings_repository.dart
lib/domain/use-cases/favourite_get_ids_use_case.dart
lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart
lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart
lib/ui/category/widgets/category_content_and_type_selection.dart
lib/ui/content_submission/view_models/content_submission_view_model.dart
lib/ui/content_submission/widgets/content_submission_description_form_field.dart
lib/ui/content_submission/widgets/content_submission_screen.dart
lib/ui/core/ui/media/app_network_image.dart
lib/ui/favourite/view_models/favourite_view_model.dart
lib/ui/favourite/widgets/favourite_button.dart
lib/ui/gallery/models/gallery_preview_route_data.dart
lib/ui/settings/view_models/settings_view_model.dart
lib/ui/weather/view_models/weather_view_model.dart
lib/ui/weather/widgets/components/weather_forecast_days_list.dart
lib/ui/weather/widgets/components/weather_forecast_hourly_list.dart
lib/ui/weather/wmo_weather_icon_mapper.dart
test/data/repositories/event_repository_impl_test.dart
test/data/repositories/place_repository_impl_test.dart
test/integration/all_day_pipeline_test.dart
test/support/fake_repositories.dart
test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart
test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart
test/ui/content_submission/view_models/content_submission_view_model_test.dart
test/ui/content_submission/widgets/content_submission_screen_test.dart
test/ui/core/ui/media/app_network_image_test.dart
test/ui/favourite/view_models/favourite_view_model_test.dart
test/ui/favourite/widgets/favourite_button_test.dart
test/ui/gallery/models/gallery_preview_route_data_test.dart
```

Only tasks.md changes among the four planning artifacts. Proposal, design (including remediated D4/D5), metadata/skip_specs and canonical specs are byte-identical to apply preflight.

### Test verification

All commands used `flutter test --no-pub --reporter json` on the final formatted candidate. Counts below exclude hidden loading/setup events; no assertions weakened, skips added, helpers duplicated or tests removed.

| Run | Passed | Failed | Skipped | Exit |
| --- | ---: | ---: | ---: | ---: |
| Initial gallery-focused run | 44 | 0 | 0 | 0 |
| Final focused run, 24 explicit suites | 638 | 0 | 1 | 0 |
| Full Flutter suite | 2213 | 0 | 6 | 0 |

The focused command supplied exactly the following suite paths after the common flags:

| Suite | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| `test/ui/content_submission/view_models/content_submission_view_model_test.dart` | 132 | 0 | 0 |
| `test/ui/content_submission/widgets/content_submission_screen_test.dart` | 37 | 0 | 0 |
| `test/ui/content_submission/widgets/content_submission_fields_test.dart` | 6 | 0 | 0 |
| `test/ui/content_submission/widgets/content_submission_progress_screen_test.dart` | 32 | 0 | 0 |
| `test/integration/all_day_pipeline_test.dart` | 0 | 0 | 1 |
| `test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart` | 97 | 0 | 0 |
| `test/ui/gallery/models/gallery_preview_route_data_test.dart` | 44 | 0 | 0 |
| `test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart` | 62 | 0 | 0 |
| `test/ui/content_submission/widgets/content_submission_description_form_field_test.dart` | 13 | 0 | 0 |
| `test/ui/favourite/view_models/favourite_view_model_test.dart` | 17 | 0 | 0 |
| `test/ui/favourite/widgets/favourite_button_test.dart` | 7 | 0 | 0 |
| `test/data/repositories/event_repository_impl_test.dart` | 76 | 0 | 0 |
| `test/data/repositories/place_repository_impl_test.dart` | 37 | 0 | 0 |
| `test/data/repositories/settings_repository_impl_test.dart` | 7 | 0 | 0 |
| `test/data/sources/settings_local_data_source_test.dart` | 3 | 0 | 0 |
| `test/ui/settings/view_models/settings_view_model_test.dart` | 2 | 0 | 0 |
| `test/ui/settings/widgets/settings_screen_test.dart` | 5 | 0 | 0 |
| `test/ui/core/ui/media/app_network_image_test.dart` | 7 | 0 | 0 |
| `test/ui/post/widgets/components/post_media_slideshow_test.dart` | 3 | 0 | 0 |
| `test/ui/category/view_models/category_view_model_test.dart` | 5 | 0 | 0 |
| `test/ui/weather/view_models/weather_view_model_test.dart` | 21 | 0 | 0 |
| `test/ui/weather/widgets/components/weather_forecast_days_list_test.dart` | 3 | 0 | 0 |
| `test/ui/weather/widgets/components/weather_forecast_hourly_list_test.dart` | 6 | 0 | 0 |
| `test/ui/weather/widgets/weather_forecast_button_test.dart` | 16 | 0 | 0 |

The full run used no path arguments. Six existing skipped cases, with their skip declarations checked against the preflight files:

- `test/integration/external_event_token_pipeline_test.dart`: real authenticated Dart preview/apply preserves PostgreSQL microsecond tokens, rejects drift and retries a lost committed response.
- `test/integration/all_day_pipeline_test.dart`: edited requests survive local publication, cache and Rome rendering.
- `test/utils/command_it_disposal_behavior_test.dart`: A upstream-like captures current StateError after dispose; checks notifier safety.
- `test/utils/command_it_disposal_behavior_test.dart`: B runAsync captures current StateError after dispose; checks notifier safety.
- `test/utils/command_it_disposal_behavior_test.dart`: E Molise reporting captures current StateError after dispose; checks notifier safety.
- `test/routing/geo_map_route_test.dart`: NAV-01 [upstream #188018] inactive Post branch must not consume Map root Back.

The focused skip is the existing all-day local E2E environmental gate MOLISE_ALL_DAY_LOCAL_E2E. It was selected and skipped, not executed successfully. No opt-in backend/device configuration was changed to bypass these gates.

### Analyzer identity comparison

The final analyzer ran after the complete test suite on the same source hashes and exited 1 solely for the retained out-of-scope infos:

| Rule | Before | After |
| --- | ---: | ---: |
| unawaited_return_in_try_block | 1 | 0 |
| experimental_member_use | 3 | 0 |
| avoid_catching_errors | 1 | 0 |
| avoid_positional_boolean_parameters | 15 | 0 |
| deprecated_member_use_from_same_package | 125 | 125 |
| async_return_with_no_await | 57 | 57 |
| Total | 202 | 182 |

After: zero errors, zero warnings, 182 info. Full multiset comparison preserves severity, exact message, rule, file, column and diff-mapped line; zero new or missing residual identities. Seventeen residual occurrences shifted. Two diagnostics in fake_repositories.dart required explicit source reconciliation because their return expressions gained named save arguments and formatter reflow: 626:5→627:5 and 902:5→905:5. Normalized comparison confirms the same handler argument value, return and fallback, without await or async lifecycle changes. Remaining shifts map unchanged diagnostic source lines. The independent reviewer reproduced the complete identity comparison.

### Review, formatting, validation and scope

- Independent reviewer performed a read-only adversarial audit of the final production/test diff, call paths, locked dependency behavior, semantic equivalence, F1, test assertions, diagnostic ledger and baseline hash inventory. No material finding remained; no review-driven runtime change was required. Reviewer independently confirmed focused/gallery results and the existing all-day skip. The complete suite and final report were verified by the main agent after that review completed.
- dart format applied only to the 34 touched Dart files. Final `dart format --output=none --set-exit-if-changed` on those exact paths: exit 0, 34 files, zero changes. Source hashes stayed unchanged throughout final focused/full tests and final analyzer.
- git diff --check and git diff --cached --check: exit 0. Untracked PR3 artifacts separately compared to their preflight bytes and whitespace-audited, because normal git diff does not cover them.
- openspec validate resolve-flutter-analyzer-diagnostics-pr3 --strict --no-interactive: exit 0; specs recognized as skipped. All 22 tasks completed against observed results.
- Hash audit limits introduced edits to the 34 listed Dart files and this tasks artifact; 1032 other preexisting files preserved, including AGENTS.md and three frozen PR3 artifacts. No new/removed non-ignored file, staging change, generator/schema/backend/Supabase/dependency/analyzer/CI/other-change/main-spec change. Branch and HEAD unchanged; no commit/push/PR/sync/archive.

### Evidence and limits

Raw outputs, baseline snapshots, before/after ledgers, comparison script/report, command/path manifests, per-suite summaries and scope/candidate hashes are retained under `/tmp/moliseis-pr3-apply/` (ephemeral). This report preserves the verified results and exact focused/changed path lists.

Quill tests prove editor projection/lifecycle, not native external rich clipboard behavior. Preservation is supported by the unchanged false configuration and locked dependency source audit; optional device smoke testing was not performed. Category/image typedef changes and all WMO mappings are also supported by source equivalence; existing suites are not claimed to provide exhaustive callback timing or night/fallback coverage. The six opt-in/upstream skipped tests remain coverage limitations, not newly introduced skips. Analyzer intentionally remains red for the 182 preexisting infos and is not made a required merge gate.

Acceptance: IMPLEMENTED — READY FOR EXTERNAL ADVERSARIAL REVIEW. No unresolved material finding or acceptance failure remains. Implementation completion does not authorize commit, publishing, merge, spec synchronization or archive.
