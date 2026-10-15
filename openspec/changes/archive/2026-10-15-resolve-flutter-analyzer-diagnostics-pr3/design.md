## Context and baseline

See `proposal.md`. The GitHub `main` sources and PR2 archive were inspected on 2026-10-14. The 15 positional-boolean occurrence positions below come from the prior full CI analyzer ledger; PR2 did not target those rules, but positions are not contractual. Recompute line numbers, counts, affected callers and test ownership from the actual apply checkout; do not assume the tree is clean. Scope is four precise rules and their necessary call-site/test propagation.

**Diagnostic matrix (baseline identities):**

| Rule | Occurrences | Primary source |
| --- | ---: | --- |
| `unawaited_return_in_try_block` | 1 warning | `lib/ui/content_submission/view_models/content_submission_view_model.dart` (`_submit`, historical 799) |
| `experimental_member_use` | 3 warnings | `lib/ui/content_submission/widgets/content_submission_description_form_field.dart` (`clipboardConfig`, `QuillClipboardConfig`, `enableExternalRichPaste`, historical line 150) |
| `avoid_catching_errors` | 1 info | `lib/ui/gallery/models/gallery_preview_route_data.dart` (`on ArgumentError`, historical 141) |
| `avoid_positional_boolean_parameters` | 15 info | 11 production/test declaration files detailed below |

**All 15 positional-boolean declaration identities**, historical positions:

| # | Path | Declaration / targeted contract | Position |
| ---: | --- | --- | --- |
| 1 | `lib/domain/repositories/event_repository.dart` | `setFavouriteEvent(int id, bool save)` | 67:50 |
| 2 | `lib/domain/repositories/place_repository.dart` | `setFavouritePlace(int id, bool save)` | 45:50 |
| 3 | `lib/domain/repositories/settings_repository.dart` | `setCrashReporting(bool enable)` | 45:42 |
| 4–5 | `lib/domain/use-cases/favourite_get_ids_use_case.dart` | `setFavouriteEvent` / `setFavouritePlace` | 29:50, 32:50 |
| 6 | `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | `setEventEnabled(bool enabled)` | 321:24 |
| 7 | `lib/ui/category/widgets/category_content_and_type_selection.dart` | `_buildSelectionRow` callback `void Function(bool?) onChanged` | 220:28 |
| 8–9 | `lib/ui/content_submission/view_models/content_submission_view_model.dart` | `setEventEnabled(bool enabled)` / `setAcceptedTerms(bool? value)` | 659:24, 726:25 |
| 10 | `lib/ui/core/ui/media/app_network_image.dart` | `void Function(bool isLoading)? onImageLoading` | 41:23 |
| 11 | `lib/ui/favourite/view_models/favourite_view_model.dart` | `setFavourite(ContentBase content, bool save)` | 62:58 |
| 12 | `lib/ui/weather/wmo_weather_icon_mapper.dart` | `iconForCode(int weatherCode, bool isDay)` | 66:41 |
| 13–14 | `test/support/fake_repositories.dart` | `setFavouriteEventHandler` / `setFavouritePlaceHandler` function types | 519:41, 817:41 |
| 15 | `test/ui/core/ui/media/app_network_image_test.dart` | test helper callback `void Function(bool isLoading)?` | 21:17 |

## Design decisions and invariants

### D1 — Only scoped rules; diagnostic identity preservation

At apply preflight capture all `flutter analyze --no-pub` diagnostics including severity, exact message, rule, file and position; record command/exit. Expected historical 202 = 4 warnings + 198 info, with target 20. Use a diff-aware mapping of post-edit positions to distinguish shifts from new diagnostics. All four target rules must reach zero, and **the 182 residual identities** must remain unchanged apart from justified location shifts. Aggregate counts are not sufficient. If a newly introduced target appears in a necessary caller/test, fix within scope; substantive unrelated drift requires reconciliation, not ignoring or expanding silently. Analyzer exit 1 is acceptable only for previously known, out-of-scope infos. No analysis config, global suppression or required-check change.

### D2 — Submission completion and ownership

In `_submit`, the already-acknowledged branch is `return _finalizeSubmittedSession(draft.clientSubmissionId);` inside `try` with `finally` releasing ownership **only when `!acknowledged`**. Use `return await` at this exact point, preserving the already-set `_submissionFinalizationPending = true` and `acknowledged = true`. Do not move the call outside the `try`, change the guard, wrap errors, add catch handlers, or touch the existing legacy Command. Inspect `_prepareSubmissionAttempt`, `_releaseSubmissionOwnership`, `_finalizeSubmittedSession`, `_serialize`, session retirement and retry handling before apply. Validate: pending finalization keeps captured submission identity; async completion/result semantics; local-finalization error retains retry authority; retry succeeds without double remote submit; non-acknowledged failure still releases ownership. Use deterministic `Completer`/fake repo barriers, not sleeps or racy pump timing. Preserve Result/Command reporting and explicit disposal semantics. Do not change unrelated `return` sites.

### D3 — Gallery parser rejects malformed timestamps without Error catches

`_tryParseMedia` currently performs field shape checks, then catches `ArgumentError` around `DateTime.fromMillisecondsSinceEpoch` and `Media` construction. `Media` has a const constructor with no validation assertions. Replace this broad catch with explicit `createdAt` and `modifiedAt` bounds validation **before** construction; use DateTime's supported millisecond epoch range inclusive [-8640000000000000, 8640000000000000], verified against the locked Dart SDK on the relevant platforms. Make the smallest possible change and avoid a new generic parser abstraction. Keep DateTime local/default construction, field typing/nullability, allowed negative dimensions, URL fields, order and initial-index validation unchanged. Do not catch `Exception` as a substitute or suppress the lint. Tests already cover both invalid endpoints, ±(2^63), inclusive boundary acceptance, nullables, roundtrip and deterministic arbitrary payloads; add tests only for a real contract gap (e.g. modifiedAt valid lower/upper bounds). The parser must return `null`, not throw, for its specified malformed primitive payloads.

### D4 — Application boolean contracts: named `required` parameters

Adopt the existing argument names and semantics rather than inventing synonyms:

- `EventRepository.setFavouriteEvent(int id, {required bool save})`, `PlaceRepository.setFavouritePlace(int id, {required bool save})`; propagate to concrete ObjectBox repository implementations, `FavouriteGetIdsUseCase`, `FavouriteViewModel._persistFavourite`, fake repo overrides, handler invocations and every caller/test. `FavouriteViewModel.setFavourite(ContentBase content, {required bool save})`. Preserve optimistic state transitions, idempotent IDs/captures, `Result.error` rollback, concurrency gate, and event/place switching. Named-parameter source APIs are intentionally changed; no persistent/backend contract is changed.
- `SettingsRepository.setCrashReporting({required bool enable})`; update its concrete implementation, fake implementation and `SettingsViewModel._setCrashReporting` repository invocation. **Do not** change `_setCrashReporting(bool)` or its legacy `Command1<void,bool>` binding; that callback is a deliberate positional Command input and is outside the target lint. Preserve optimistic update/revert and `SentryLoggingFlag` update ordering.
- `AdminSubmissionEditorViewModel.setEventEnabled({required bool enabled})` and `ContentSubmissionViewModel.setEventEnabled({required bool enabled})`; update their respective screen callbacks, tests and integration cases; preserve existing admin external-event inability to disable event mode and the existing temporal draft/date reset/dirty rules.
- `ContentSubmissionViewModel.setAcceptedTerms({required bool? value})`; preserve tri-state null/false/true semantics; update widget and test call sites only.
- `WmoWeatherIconMapper.iconForCode(int weatherCode, {required bool isDay})`; update weather ViewModel, daily/hourly widgets/tests. Preserve all day/night WMO mappings and unknown-code fallback.

**Event-mode callback adaptation (F1):** `lib/ui/content_submission/widgets/content_submission_screen.dart` currently assigns the direct tear-off `widget.viewModel.setEventEnabled`, and `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart` assigns `viewModel.setEventEnabled`, to `ContentSubmissionFields.onEventChanged`. The planned `void setEventEnabled({required bool enabled})` signature is not directly compatible with the positional `ValueChanged<bool>` callback. Replace these two tear-offs with positional closures at the screen call sites, retaining each screen's existing ViewModel receiver:

```dart
// Content submission screen
onEventChanged: (enabled) =>
    widget.viewModel.setEventEnabled(enabled: enabled),

// Admin submission editor screen
onEventChanged: (enabled) =>
    viewModel.setEventEnabled(enabled: enabled),
```

`ContentSubmissionFields.onEventChanged` must remain `ValueChanged<bool>`. Each callback invocation forwards the received boolean unchanged and invokes its setter exactly once. Preserve event-mode enable/disable semantics, including the existing admin external-event restriction and temporal draft/date reset/dirty rules. Do not change the underlying Flutter APIs or add any adapter or wrapper beyond these two necessary closures.

Respect existing architecture: repository interface → concrete implementation → use case → ViewModel → widget. No new packages, Commands or intermediary abstractions. Do not modify internal implementation boolean locals/arguments where not required to satisfy the target rule. Recompute complete call graph with `rg` rather than relying solely on search snippets.

### D5 — Flutter callback types: preserve positional signature with standard typedefs

For `_buildSelectionRow` change `void Function(bool?) onChanged` to `ValueChanged<bool?> onChanged`; preserve nullable values, invocation and StatefulBuilder state behavior, using already imported Flutter/material_ui symbols. For `AppNetworkImage.onImageLoading` and the associated `_buildTestApp` helper callback use `ValueChanged<bool>?`, preserving nullable callback, `true` while loading, `false` when loaded and exact frameBuilder timing. These are Flutter-compatible **positional callbacks**; do not change them into named-argument function types or introduce wrapping adapters. Ensure resolved `ValueChanged` symbol imports compile without unrelated changes. Do not rewrite `Checkbox.onChanged` or image loading logic.

The no-adapter instruction above applies to these equivalent category/image callback type substitutions; it does not prohibit the two screen closures required by D4 to connect the named event-mode setters to the unchanged positional widget callback.

### D6 — Test fake handler contracts

`test/support/fake_repositories.dart` defines `Future<Result<void>> Function(int id, bool save)?` for event/place handlers. Prefer `Future<Result<void>> Function(int id, {required bool save})?` and propagate handler invocations plus all assigned anonymous functions in favourite tests; retain deterministic fake capture (`setFavourite*Calls`) and controllable results. Do not add lint exceptions for these fake signatures or introduce unnecessary typedefs. Verify no new diagnostics appear in test closure declarations.

### D7 — Quill experimental boundary: explicit narrow exception

`flutter_quill` 11.6.0 exposes experimental `QuillControllerConfig.clipboardConfig`, `QuillClipboardConfig` and `enableExternalRichPaste`. Current code explicitly uses `enableExternalRichPaste: false`. Upstream Quill controller implementation defines `enableExternalRichPasteDefault = true` when the setting is null. Removing the config therefore changes behavior and is rejected. Do not upgrade, fork, reimplement the clipboard, alter the toolbar, or replace with default. At apply verify the exact locked version and source for an equivalent stable public API. If none exists, retain the **single-line** existing configuration and add one immediately preceding `// ignore: experimental_member_use` with an adjacent rationale: experimental Quill API is required to disable external rich-text paste. Confirm all three warnings disappear and the configured value remains false. Suppression is accepted only here, not as a general strategy. Existing widget tests verify editor projection/lifecycle; source/configuration verification and, if realistically testable with the existing harness, a focused clipboard behavior test should complement them. Never claim tests prove native external-rich-paste behavior when they only inspect editor initialization; document this limitation and any manual smoke check as optional/non-blocking.

### D8 — No generator/backend/feature drift

PR3 does not intentionally change generator inputs, ObjectBox schema, generated .g.dart/.mapper.dart, Supabase migrations/RPCs, dependencies/pubspec, `AGENTS.md`, analysis options, workflow/branch protection, historical OpenSpec archives or canonical specs. Should a necessary scoped edit touch generator inputs, stop and reassess rather than silently accepting generated drift. Preserve local tracked/untracked/staged user work. No bulk formatting; apply `dart format` only to touched source/test files and review resulting diffs. `git diff --check` and `git diff --cached --check` must pass for introduced edits.

### D9 — Tests and behavioral evidence

Existing relevant suites (verify paths on apply):

- `test/ui/content_submission/view_models/content_submission_view_model_test.dart`, `test/ui/content_submission/widgets/content_submission_screen_test.dart`, `test/integration/all_day_pipeline_test.dart`: submit/finalization/retry and event-mode/terms callbacks.
- `test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart` and `test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart`: admin event-enable/external-event constraints.
- `test/ui/gallery/models/gallery_preview_route_data_test.dart`: timestamp bounds, roundtrip, malformed/no-throw parsing.
- `test/ui/content_submission/widgets/content_submission_description_form_field_test.dart`: editor init, text/Delta synchronization, lifecycle.
- `test/ui/favourite/view_models/favourite_view_model_test.dart`, `test/ui/favourite/widgets/favourite_button_test.dart`, `test/data/repositories/event_repository_impl_test.dart`, `test/data/repositories/place_repository_impl_test.dart`: favourite propagation/rollback/fake-handler behavior.
- `test/ui/core/ui/media/app_network_image_test.dart`; existing category/weather/settings suites discovered with `rg --files test` during preflight: callback event semantics, WMO mappings, Sentry setting persistence and failure rollback.

Before writing a new test, locate existing coverage and state the missing invariant; add only narrowly scoped deterministic tests. Do not weaken assertions or add skips. Run focused suites followed by full `flutter test --no-pub --reporter json`, capture exit/pass/fail/skip counts; investigate all failures and establish any preexistence rather than labeling them automatically benign. Prior PR2 full-run evidence (2213 passes, six existing skips) is a reference, not a guaranteed post-PR3 result.

### D10 — Planning, scope, review and release

Use OpenSpec's `spec-driven` schema with `.openspec.yaml` (`created: 2026-10-14`, `skip_specs: true`), `proposal.md`, `design.md`, `tasks.md`. A `skip_specs` classification is justified by unchanged canonical product behavior, **not** by denying the deliberate Dart named-parameter source API changes. Validate active change with `openspec validate resolve-flutter-analyzer-diagnostics-pr3 --strict --no-interactive` and inspect status. Planning phase only writes these four files. Do not sync/archive until implementation is reviewed, merged and separately authorized. Independent adversarial review required before apply and for final implementation diff. Analyzer remains intentionally red for 182 preexisting infos and is not a required check. There is no authorization for commit/push/PR/merge in planning.

## Failure-mode summary

- Submission: treating lint-only change as harmless can mask ownership/retry changes; use constrained one-line fix and deterministic session-finalization tests.
- Gallery: replacing an Error catch with `on Exception` does not solve the lint correctly and can leak invalid epoch RangeErrors; validate timestamp bounds and verify both endpoints.
- API propagation: a public named-parameter refactor can compile locally but miss overrides, closures, fake handlers, navigation/widget calls; enumerate/compile/test all consumers.
- Flutter callbacks: changing `ValueChanged<bool>` contracts into named args breaks framework callbacks; retain positional typedefs.
- Quill: deleting the experimental configuration silently enables rich external paste; keep disabled and narrowly suppress with documented justification.
- Analyzer: a lower aggregate count can hide new diagnostics; compare stable identities, not totals alone.
