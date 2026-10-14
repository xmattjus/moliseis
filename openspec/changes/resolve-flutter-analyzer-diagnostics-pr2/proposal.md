## Why

PR2 removes 76 analyzer info diagnostics after PR1, keeping the cleanup reviewable and behavior unchanged. The analyzer will remain intentionally red for preexisting diagnostics outside the three target rules.

## What Changes

The planned implementation was:

- Stable-partition named parameters in the 16 files enumerated in design.md: required first, optional second, preserving relative order within each group (73 diagnostics).
- Add only `@immutable` to `AppPulseEffect`, using its existing foundation import (2 diagnostics).
- Add `dart:async` and wrap only the automatic constructor call with `unawaited(sync.execute(false))` in `SyncViewModel` (1 diagnostic).
- Reuse existing tests and run the standard build_runner workflow after changing the six generator inputs. Audit every generated diff and verify reproduction from final sources; compatible old outputs alone do not satisfy this gate. No new tests are justified solely by lint removal.

During the planning phase, this request created planning artifacts only. No production or test fix was authorized at that stage.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Public contracts, canonical sync, event temporal semantics, moderation, local retrieval and command requirements remain unchanged. No delta or main specs. `.openspec.yaml` follows PR1 metadata (`schema: spec-driven`, audit-date `created`, `skip_specs: true`); installed OpenSpec 1.12.0 instructions explicitly support skipping specs for behavior-neutral changes, and status confirms `specs: skipped`.

## Impact

The planned manual production edits were limited to the original 18 Dart files: 16 parameter-order files, one painting effect and one existing legacy-command consumer. Generated outputs were permitted only when verified and attributed under gate D2 to synchronize the three DTO mappers and ObjectBox bindings with the final inputs; their exact diff was established by generation, not assumed in advance. No dependency, schema, API contract, call-site or CI change. Details, exact occurrence positions and existing test paths are in design.md. The planning delivery contained only four planning artifacts. PR #5 now contains the verified implementation and its completed apply report.

## Baseline verified

Audit date: 2026-10-14. HEAD `1c64537d3fdae33a2ba6bee2fe7db32a580b691e`, branch `main`, equals the requested baseline; ancestry check exit 0, no subsequent commits. Initial status contains only ` M AGENTS.md`; no staged or untracked changes. That unrelated tracked modification is preserved and excluded. No target source drift. PR1 reference: https://github.com/xmattjus/moliseis/pull/3 and the four archived artifacts at `openspec/changes/archive/2026-10-14-resolve-flutter-analyzer-diagnostics/`, read without modification.

Flutter 3.47.5 stable (`6a19cca564`), Dart 3.13.4, OpenSpec 1.12.0. Resolved dependencies: very_good_analysis 11.0.0, command_it 9.5.2, skeletonizer 3.0.0, ObjectBox/runtime Flutter libs/generator 5.3.2, dart_mappable runtime 4.10.0 / builder 4.8.0, build_runner 2.15.1. `pubspec.yaml` requests Dart ^3.11.5 / Flutter 3.47.5; lockfile and local package resolution were inspected. No updates planned.

Observed `flutter analyze --no-pub`: exit 1, 0 errors / 4 warnings / 274 info / 278 total. Targets exactly match historical 73 + 2 + 1 = 76 info. With this unchanged baseline the projected remainder is 0 errors / 4 warnings / 198 info / 202 total. These are estimates, not results of implementation; acceptance requires zero target diagnostics and zero new diagnostic identities after diff-aware comparison. Tests have been inspected, not executed during planning.

## Scope and Non-goals

Only the three named rules are in scope. D1–D10 in design govern execution. Excluded: all other diagnostics, including `async_return_with_no_await`, `avoid_positional_boolean_parameters`, `unawaited_return_in_try_block`, `avoid_catching_errors`, `experimental_member_use` and legacy deprecations; Command migration or command_it refactoring; changes to equality/hash semantics, painting or sync behavior/lifecycle; new abstractions/dependencies or version updates; opportunistic cleanup, naming changes, mass formatting; suppressions/ignore_for_file; analyzer options/rules/exclusions, CI workflows or required checks; AGENTS.md; Supabase/SQL/RPC/Edge Functions/RLS; database migrations/ObjectBox schema; unrelated generated drift or manual generated-code edits; main specs or the PR1 archive. The only controlled generated-output exception is the synchronized, contract-preserving, reproducible output described in D2. The planning request did not authorize implementation, commit, push, PR, merge, spec sync or archive. External adversarial review and explicit authorization were required before apply.
