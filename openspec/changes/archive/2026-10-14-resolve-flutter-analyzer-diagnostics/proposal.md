## Why

PR 1 removes 13 mechanical Flutter analyzer diagnostics without changing application behavior. Keeping this cleanup separate makes semantic neutrality reviewable before any broader analyzer work.

## What Changes

- Remove only the redundant `one_member_abstracts` ignore in `lib/utils/logging/logger.dart` (1 diagnostic).
- Replace the three unresolved `[fn]` Dartdoc references in `lib/domain/core/sync_transaction_coordinator.dart` with inline backticks, retaining transaction and `Result.error` rollback documentation (3).
- Remove only four unnecessary `unawaited` wrappers in `lib/ui/post/widgets/components/post_media_slideshow.dart`; preserve call order, lifecycle and `dart:async` for the part file (4).
- Minimally reorganize one long string expression in each weather forecast list and split two long skip-message literals in `test/utils/command_it_disposal_behavior_test.dart`, preserving their exact runtime text (4).
- Replace only the post-reconciliation `await Link(...).exists()` assertion with `Link(...).existsSync()` in `test/data/repositories/content_submission_staged_asset_repository_impl_test.dart` (1).

## Capabilities

### New Capabilities

None. No new application requirements or behavior.

### Modified Capabilities

None. Existing contracts remain authoritative; no delta specs or main-spec updates. `.openspec.yaml` uses `schema: spec-driven` and `skip_specs: true`, supported by installed OpenSpec 1.12.0 and confirmed by CLI status reporting specs as skipped.

## Impact

Seven existing Dart files, five existing targeted test files and these planning artifacts. No public interface, dependency, backend, persistence, generated-code or CI contract changes. Existing tests are reused; implementation is not authorized by this planning request.

## Non-goals

All diagnostics outside `unnecessary_ignore`, `comment_references`, `lines_longer_than_80_chars`, `unnecessary_unawaited` and `avoid_slow_async_io` are excluded, including legacy Command deprecations/migration, `async_return_with_no_await`, parameter-order/positional-boolean lints and `experimental_member_use`. No command_it bug fix, new abstraction/dependency, Supabase/SQL/RPC/Edge Function/RLS change, ObjectBox/generated-code change, AGENTS.md edit, CI workflow/analyzer gate change, lint configuration/suppression, mass formatting, opportunistic refactor, PR 2–5 work, unjustified main-spec update, spec sync or archive.

## Baseline verified

Audit on 2026-10-14: HEAD `8dce91da9cf1e8bdc0e2c36d938c76acc6116e87` equals the requested historical baseline (no commit drift). Initial `git status --short`: ` M AGENTS.md`, an unrelated preexisting addition of GitHub contribution rules, preserved. No target Dart files differ from HEAD.

Flutter 3.47.5 stable (framework `6a19cca564`), Dart 3.13.4, OpenSpec 1.12.0. `very_good_analysis: ^11.0.0` resolves to 11.0.0; `command_it: ^9.5.2` resolves to 9.5.2. `analysis_options.yaml` includes the package default, existing generated/platform exclusions, `todo: info`, const preferences and disabled public API docs lint; it remains unchanged.

`flutter analyze --no-pub` ran successfully as an analysis operation and exited 1: 0 errors, 4 warnings, 287 info, 291 total. Targets are exactly 1 + 3 + 4 + 4 + 1 = 13 info, with no diagnostic drift from historical counts. At an unchanged baseline, expected post-cleanup counts are 0 errors, 4 warnings, 274 info, 278 total; acceptance instead requires all target diagnostics eliminated and no new diagnostics. Full distribution and positions are in design.md. Tests are planned, not run during authoring.
