## Why

After analyzer cleanup PR1 and PR2, the next coherent round targets four remaining Dart/very_good_analysis rules whose fixes cross source contracts, async-finalization ordering, external route parsing, and a dependency's experimental API. PR3 should reduce diagnostics without changing user-visible behavior, persistence, or runtime policy. Unlike previous mechanical rounds, behavior-sensitive regression evidence is required.

## Baseline and provenance

Planning audit: 2026-10-14; GitHub `main` at `6ccc62635d033747159d37c718ad38d961de8376` (PR2 archive merge, PR #6). PR2 implementation was squash-merged as `21fb2471a2aafe46aed0be4a3fcf8319904452ca` (PR #5). PR2's verified analyzer ledger is **202 total = 0 errors, 4 warnings, 198 info**; the PR3-specific target is **20 = 4 warnings + 16 info**. Projected residual after PR3: **182 info, zero warnings and zero errors** (125 legacy Command deprecations + 57 async-return diagnostics). These are verified historical/current-branch sources and a projection, **not** a newly executed local analyzer run. At planning/apply preflight rerun `flutter analyze --no-pub` and reconcile identities and any drift.

Repository configuration includes `package:very_good_analysis/analysis_options.yaml`; PR2 reports Flutter 3.47.5, Dart 3.13.4, very_good_analysis 11.0.0, `command_it` 9.5.2 and OpenSpec 1.12.0. Verify actual tools and `pubspec.lock` at apply, with no updates. The reviewed source is the GitHub `main` snapshot, not an inspected local working tree; implementers must inventory/stabilize local ownership before editing.

## What changes

- Eliminate one `unawaited_return_in_try_block` warning in `ContentSubmissionViewModel._submit` while preserving submit ownership/finalization/retry invariants.
- Eliminate one `avoid_catching_errors` info in `GalleryPreviewRouteData._tryParseMedia` with explicit timestamp bounds validation, preserving its no-throw-on-malformed-input contract and existing accepted values.
- Eliminate all 15 `avoid_positional_boolean_parameters` infos by propagating named booleans through owned application methods and using `ValueChanged<bool>`/`ValueChanged<bool?>` for framework-compatible callback signatures; update all call sites, implementations, fakes, and tests.
- Eliminate three `experimental_member_use` warnings in the Quill description field **without removing** `enableExternalRichPaste: false`. Prefer a stable equivalent API if one actually exists at the locked version; otherwise allow **one documented, line-scoped `ignore: experimental_member_use`** over the existing one-line expression. Do not claim this removes dependency instability: it only documents/suppresses an accepted, isolated analyzer warning.
- Add/adjust targeted deterministic regression tests where current assertions do not prove the relevant behavior. Perform a full Flutter test/analyzer and diff-aware diagnostic audit.

## Capabilities

No new product capabilities or behavior changes. The named-boolean method APIs change at source level (all internal/owned callers must be updated); this is **not** literally an unchanged Dart signature. Canonical product specs are not modified because product behavior/requirements remain unchanged. As in PR1/PR2, `.openspec.yaml` uses `skip_specs: true` for this analyzer-focused change; verify OpenSpec accepts it and no canonical requirement is newly introduced.

## Impact and exclusions

Impacted production surfaces: content submission VM + Quill editor, gallery route parser, favourites repository contracts/implementations/use case/VM, settings repository and VM call, event-mode setters and UI callers, weather icon mapping/callers, category selection callback and network-image callback. Test fakes and tests are in scope as needed. See exhaustive occurrence matrix and propagation requirements in `design.md`.

**Non-goals:** legacy `Command`/`Command0`/`Command1` migration; `async_return_with_no_await` cleanup; removal/change of Quill rich-paste restriction; new packages or dependency/version upgrades; source/binary compatibility adapters solely for hypothetical consumers; broad code refactors; backend/Supabase migrations/functions/RPCs/RLS; ObjectBox schemas/generator output; analyzer configuration changes/global ignores; changes to CI workflows/branch protections; change to Sentry consent semantics, weather classification, favourites persistence, admin restrictions or navigation behavior; main-spec synchronization or OpenSpec archive. PR3's analyzer is expected to remain red for out-of-scope infos and must not become a required merge gate yet.

**This delivery is planning only.** No implementation, test execution, Git commit, push, PR, merge, spec sync or archive is implied or authorized by these artifacts. Independent adversarial review and explicit apply authorization precede execution.
