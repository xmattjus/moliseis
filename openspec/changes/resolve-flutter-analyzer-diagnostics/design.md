## Context and baseline

See proposal.md for motivation and exclusions. This is PR 1 only: seven files, 13 info diagnostics, no behavior changes. Audit date: 2026-10-14. HEAD equals historical baseline `8dce91da9cf1e8bdc0e2c36d938c76acc6116e87`. Initial working tree contains only ` M AGENTS.md` (GitHub contribution rules); preserve it and exclude it from this change's delivery. No source drift observed.

Observed SDK: Flutter 3.47.5 stable, framework `6a19cca564`, Dart 3.13.4; OpenSpec 1.12.0. Lockfile: very_good_analysis 11.0.0, command_it 9.5.2. Analyzer configuration includes very_good_analysis defaults, existing exclusions and local lint overrides described in proposal; no changes are planned. Flutter initially could not write its external SDK cache under the sandbox; the authorized rerun completed analysis with exit 1. This is diagnostic failure, not tool failure.

`flutter analyze --no-pub`: 0 errors / 4 warnings / 287 info / 291 total, matching historical counts. Full rule distribution:

| Rule | Count | Severity |
| --- | ---: | --- |
| deprecated_member_use_from_same_package | 125 | info |
| always_put_required_named_parameters_first | 73 | info |
| async_return_with_no_await | 57 | info |
| avoid_positional_boolean_parameters | 15 | info |
| unnecessary_unawaited | 4 | info |
| lines_longer_than_80_chars | 4 | info |
| comment_references | 3 | info |
| experimental_member_use | 3 | warning |
| avoid_equals_and_hash_code_on_mutable_classes | 2 | info |
| unawaited_return_in_try_block | 1 | warning |
| avoid_catching_errors | 1 | info |
| discarded_futures | 1 | info |
| unnecessary_ignore | 1 | info |
| avoid_slow_async_io | 1 | info |

Warning identities to preserve:
- `unawaited_return_in_try_block`: `lib/ui/content_submission/view_models/content_submission_view_model.dart:799:7`.
- `experimental_member_use`: `lib/ui/content_submission/widgets/content_submission_description_form_field.dart:150:9`, `150:26`, `150:47` (clipboardConfig, QuillClipboardConfig, enableExternalRichPaste).

## Goals / Non-Goals

Remove every currently observed diagnostic for the five target rules while preserving runtime values, call ordering, contracts and lifecycle. Keep the diff auditable and reuse existing tests. Non-goals are the exhaustive exclusions in proposal.md, especially any non-target analyzer fix, CI gate change or PR 2–5 implementation. No architectural change, new test infrastructure or dependency is required.

## Rule → file → modification → verification

Paths and positions refer to the audited checkout; positions can shift after edits. Each row maps every historical occurrence to an implementation task.

| Rule / count | File and baseline line:column | Minimal change | Verification / task |
| --- | --- | --- | --- |
| unnecessary_ignore / 1 | `lib/utils/logging/logger.dart` 8:12 | Delete only redundant ignore comment; keep Logger interface | Interface diff + analyzer; 1.1 |
| comment_references / 3 | `lib/domain/core/sync_transaction_coordinator.dart` 5:30, 6:27, 6:36 | Replace three `[fn]` links with inline `fn` backticks, retaining transaction/Result.error rollback prose | Documentation diff + analyzer; 1.2 |
| lines_longer_than_80_chars / 1 | `lib/ui/weather/widgets/components/weather_forecast_days_list.dart` 140:81 | Minimally reorganize the expression using the simplest D2 technique that removes the lint after dart format; preserve dailyData.precipitationProbabilityMax[index], leading space and % | Post-format target-lint absence + exact Text value/evaluation-order/style/structure review + days test; 1.3 |
| lines_longer_than_80_chars / 1 | `lib/ui/weather/widgets/components/weather_forecast_hourly_list.dart` 189:81 | Minimally reorganize the expression using the simplest D2 technique that removes the lint after dart format; preserve index == currentHour, currentTemperatureCelsius branch and conditional toStringAsFixed(1)/° branch | Post-format target-lint absence + conditional evaluation/order/value/style/structure review + hourly test; 1.4 |
| lines_longer_than_80_chars / 2 | `test/utils/command_it_disposal_behavior_test.dart` 305:81, 306:81 | Split adjacent skip literals retaining exact spaces/text and condition | Exact skip comparison + command_it test; 1.5 |
| unnecessary_unawaited / 4 | `lib/ui/post/widgets/components/post_media_slideshow.dart` 183:13, 243:7, 244:7, 263:7 | Unwrap forward(from: 0), ticker.start, forward, animateToPage, without adding await or altering arguments/order | Main/part import and lifecycle diff + slideshow test; 2.1–2.2 |
| avoid_slow_async_io / 1 | `test/data/repositories/content_submission_staged_asset_repository_impl_test.dart` 108:22 | Replace only await Link(...).exists() with Link(...).existsSync() | Reconcile/link/outside-file order + repository test; 3.1 |

Total: 1 + 3 + (1 + 1 + 2) + 4 + 1 = 13. Dartdoc inline text avoids introducing imports or changing interface scope solely to link a parameter that is not visible from class documentation.

## Decisions

- **D1 — Semantic neutrality.** Static cleanup only; preserve public contracts, error handling, autoplay, animation/ticker/controller lifecycle, pause/resume and gallery flow. Removing wrappers keeps the existing invocation semantics; do not replace them with awaited work or redesign callbacks.
- **D2 — Minimal diff.** Edit only the mapped occurrences and formatter consequences in those seven files. Choose the simplest minimal expression reorganization compatible with dart format and lines_longer_than_80_chars; do not prescribe a single wrapping technique. Multiline interpolated expressions (when syntactically appropriate), adjacent literals (when sufficient), or a local value (only when needed for readability and unchanged behavior) are allowed. Splitting off a suffix alone is insufficient if the formatted interpolated line still exceeds 80 characters including indentation. Preserve evaluation timing/order; no extracted helpers, new abstractions, public-contract changes, changed values or mass formatting. Broad automatic lint fixing would exceed scope.
- **D3 — Preserve part-file imports.** Keep `import 'dart:async';` in the slideshow library. Its part `_post_media_slideshow_pause_button.dart` still legitimately uses unawaited at lines 119–131. Do not edit that part or remove its wrappers; inspecting only the main file would give an incorrect unused-import conclusion.
- **D4 — Preserve asynchronous ordering.** Only the link existence assertion becomes synchronous, after `await repository.reconcileAndLoad(sessionA)` and the success assertion. Preserve symlink setup → reconciliation completion → link removal assertion → external file integrity assertion. Other filesystem operations remain untouched.
- **D5 — Preserve upstream regression characterization.** Keep condition `scenario == 'StateError'`, all test expectations and upstream characterization. Exact skip text: `command_it 9.5.2: late StateError after dispose causes upstream notifier use-after-dispose. Re-enable after an upstream fix.` Preserve concatenated spaces byte-for-byte. Neither enabling the skipped cases nor fixing command_it belongs here.
- **D6 — Analyzer remains intentionally red.** Keep analysis_options.yaml, dependencies, suppressions and CI analyzer gate unchanged. Remaining diagnostics are expected; nonzero analyzer exit is acceptable only when caused by preexisting out-of-scope diagnostics. Aggregate reduction alone is insufficient evidence.

Weather invariants under D1/D2: days must retain the exact Text content from dailyData.precipitationProbabilityMax[index], including its leading space and `%`. Hourly must retain `index == currentHour`, `viewModel.currentTemperatureCelsius` in that branch, and `hourlyData.temperature2m[index].toStringAsFixed(1)` plus `°` only in the other branch. Do not hoist a temperature read into unconditional evaluation or change the observable evaluation order, including relative to neighboring widget expressions. Both retain exact displayed text, styles and functional widget structure. Any local value must preserve those constraints. Verify semantic equivalence by source-expression review and verify lint elimination on the result after dart format; passing widget tests alone is insufficient.

## Risks / Trade-offs

- Shared part import accidentally deleted → explicitly inspect the library/part boundary and unchanged part file (D3).
- Invocation order/arguments or lifecycle accidentally changed → compare the four unwrapped expressions and surrounding guards/controllers against preflight source (D1). SDK analyzer identifies these calls as await-not-required; no SDK upgrade is needed.
- String wrapping changes whitespace, numeric formatting or skip semantics → compare concatenated text/interpolations and skip branch exactly (D2/D5).
- Link check moved before async completion or security regression masked → retain the existing success/link/outside-file assertion order and run the existing symlink test (D4). No production filesystem change.
- Counts hide introduced diagnostics or moved lines look new → compare per-diagnostic identities using diff-aware positions as described below.
- Tests have limited coverage → slideshow tests cover queued image-loading callback after unmount and pause-button typography/direction, not all autoplay/gallery/ticker flows. Weather tests cover loading/list/retry and hourly scrolling lifecycle, not exact target string equivalence. Passing them is regression evidence, not proof of semantic equivalence; the minimal source diff and exact value/order review supply complementary evidence. Do not expand this cleanup into new lifecycle tests or bug fixes.

## Test strategy

All five paths were verified and inspected. Run these individually after their relevant edits (smallest relevant gates), then the full suite after formatting:

```sh
flutter test test/ui/post/widgets/components/post_media_slideshow_test.dart
flutter test test/ui/weather/widgets/components/weather_forecast_days_list_test.dart
flutter test test/ui/weather/widgets/components/weather_forecast_hourly_list_test.dart
flutter test test/utils/command_it_disposal_behavior_test.dart
flutter test test/data/repositories/content_submission_staged_asset_repository_impl_test.dart
flutter test
flutter analyze --no-pub
git diff --check
git diff --cached --check
```

Format only the seven changed Dart files named in the matrix using `dart format` with explicit paths, never lib/ or test/ directories. Audit the formatter diff; unrelated formatting drift must be resolved without discarding preexisting work. No new tests or test helpers are planned. Before any future test edits, load applicable unit-test/test-support skills; before slideshow State edits load mounted-context safety; use the static-analysis skill for verification. This planning run does not execute implementation tests or mark them passed.

## Whitespace and diff audit strategy

At preflight, record all initial modified, staged and untracked paths from git status --short, and retain both unstaged and staged diffs plus `git diff --check` and `git diff --cached --check` output/exit status outside source. Do not assume AGENTS.md is the only preexisting change. After edits run both checks again normally, recording every report; the cached check covers changes already staged. Audit any change-authored untracked artifacts too, since these git checks omit untracked files.

Compare each reported file/line/whitespace issue with the preflight diffs and source, accounting for line movement or staging changes. Problems introduced by PR 1 are blocking and must be fixed within its scope. Problems demonstrably preexisting and untouched by PR 1 may be documented without cleanup or restoration of unrelated files. Problems of uncertain origin require investigation and attribution before completion/readiness can be declared. Observable acceptance is zero whitespace problems introduced by PR 1, not necessarily a globally clean working tree. Include a scoped diff audit that distinguishes PR 1 edits from all preexisting work, even where they share a file.

## Diagnostic comparison strategy

At apply preflight, capture full analyzer stdout/stderr and exit status outside source, before editing; retain a machine-readable ledger parsed from `severity • message • path:line:column • rule` rows, plus rule/severity counts. Repeat with the same SDK, dependency resolution, options and command after implementation. This authoring run's raw capture is `/tmp/pr1-analyzer-before.txt` (ephemeral); the distribution and target/warning positions above are durable audit evidence. Refresh the capture at apply time rather than relying on that temporary file.

Compare multisets by rule, severity, message and file plus position. For unchanged files require exact line/column identity. For changed files use the actual diff to map line/column movements to the same unchanged source occurrence; inspect every unmatched item instead of dropping positions from comparison. Do not treat a moved diagnostic as new or silently match a different occurrence solely by count. Confirm the 13 mapped targets disappear, all five target-rule counts become zero, and no unmatched post-change diagnostic is introduced. Preserve all four warnings, not only their aggregate count.

If HEAD, working tree, SDK or analyzer distribution drifted, record its provenance separately before editing and reconcile against current source. Independently explain out-of-scope differences; unexplained drift or a material contradiction blocks affected implementation/readiness. Do not broaden scope to chase it. Expected 278 total / 274 info is only a cross-check when the verified baseline still equals this audit.

## Acceptance criteria

1. All currently present target diagnostics eliminated, all 13 historical occurrences accounted for, zero new diagnostics by identity/position comparison.
2. Four existing warnings preserved unless independent drift is evidenced and documented; analyzer exit 1 explained solely by preexisting excluded diagnostics.
3. Logger/coordinator interfaces and transaction/rollback documentation preserved; runtime weather text, numeric interpolation, styles and widget structure unchanged.
4. Slideshow calls/arguments/order, autoplay, animations/ticker/controller lifecycle, pause/resume/gallery guards unchanged; dart:async retained and part untouched.
5. Only the link existence assertion changes API, after awaited reconciliation; external-file integrity check retained afterward. Skip text, condition, expectations and upstream characterization unchanged.
6. Five targeted tests and full flutter test pass with existing upstream skips preserved; failures are reported and diagnosed, never hidden by weaker assertions or extra skips. A preexisting environment failure is documented as a verification limitation, not claimed success.
7. Formatting limited to changed Dart files; overall and staged whitespace checks recorded and attributed against preflight, with zero PR 1-introduced whitespace problems and no unclassified reports. Document untouched preexisting problems without outside-scope cleanup; no change-authored out-of-scope edits and all preexisting work (including AGENTS.md) preserved.
8. Proposal/design/tasks remain aligned and `openspec validate resolve-flutter-analyzer-diagnostics --strict --no-interactive` passes. Planning readiness is distinct from implementation/test readiness.

## Main specs, migration and archiving

Repository conventions use spec-driven proposal/design/tasks and capability delta specs only for requirement changes. Existing command-execution-concurrency and content-submission-local-asset-staging contracts remain unchanged; source-only wrapping/doc fixes introduce no spec-level behavior. Installed OpenSpec 1.12.0 source and `status --json` confirm valid `skip_specs: true` metadata marks specs skipped and satisfies the tasks dependency. No artificial specs/ directory, main-spec sync or main-spec edit is warranted.

No runtime migration or deployment step is needed. If a later authorized implementation must be rolled back, revert only this cohesive cleanup while preserving unrelated work. Future archiving, separately authorized after implementation and verification, must honor skip_specs and leave main specs unchanged; it is not a task in this planning request. No PR creation, merge, sync or archive is performed here. No unresolved design blockers found; adversarial review remains required before apply.
