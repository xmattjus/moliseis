Implementation checklist. Apply explicitly authorized after final external adversarial approval; checked tasks reflect completed implementation/verification evidence. Historical planning evidence remains in proposal/design. D1–D10, matrix positions, test groups T1–T5 and generator audit G govern execution. No specs are required (`skip_specs: true`). A material contradiction stops affected execution for reconciliation; it never authorizes broader fixes.

## 0. Preflight e baseline

- [x] 0.1 Record `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, ancestry and commits since `1c64537d3fdae33a2ba6bee2fe7db32a580b691e`; retain staged/unstaged diffs, untracked inventory and both whitespace-check outputs/exit codes outside source. Result: ownership/drift ledger accounts for every preexisting change, including AGENTS.md, with no reset/restore/clean (D9).
- [x] 0.2 Recheck applicable AGENTS.md, Flutter/Dart/OpenSpec versions, analysis_options.yaml, pubspec.yaml/lock and actual package resolution. Result: versions reconciled with proposal, no SDK/dependency/options/CI change or unexplained drift (D6/D8).
- [x] 0.3 Capture full `flutter analyze --no-pub` stdout/stderr and exit status; parse rule/severity/message/file/line/column ledger. Result: all current target identities and warnings mapped to the design matrix; any change from 278 total/76 targets independently explained before edits (D7).
- [x] 0.4 Recheck all matrix signatures, PaintingEffect/SDK unawaited/Command source and existing T1–T5 tests. For generator preflight G0 inspect the six inputs/five outputs, lockfile/package-resolved generator versions, source/config manifests and output snapshots/hashes; identify all preexisting staged/unstaged/untracked ownership and other outputs the command could touch. Define a safe generation environment, isolated with faithful final-source/dependency manifests whenever user work could be overwritten; refresh concurrent-change ownership. Result: generated baseline/ownership and safe-environment report validates D1–D4/D10 before implementation; no generation during planning and no unexplained overlap.

## 1. Parameter ordering

- [x] 1.1 Stable-partition named parameters in `lib/domain/models/{admin_submission,content_base,content_submission,event,media,place}.dart` (30 diagnostics) according to D1. Result: required/optional group order and relative order verified for every full signature; same names/types/defaults/nullability, const/super forwarding and descriptionDelta/assets initializers, fields and call sites unchanged; T1 tests pass.
- [x] 1.2 Stable-partition named parameters in `lib/data/dtos/{event,media,place}_dto.dart` (16 diagnostics). Result: D1 signature audit preserves keys/types/nullability/defaults/hooks/Keep-Clear-Assign semantics; regenerate the three mappers in mandatory task 1.5 and verify decoding/encoding, evaluation/representation order and named bindings under G2. T2 tests pass on accepted regenerated output; do not retain stale output solely because it compiles (D2).
- [x] 1.3 Stable-partition named parameters in `lib/data/data-sources/{event,media,place}_entity.dart` (17 diagnostics). Result: D1 category assertions/fields/ToOne-ToMany/backlinks/indexes/IDs/defaults unchanged; task 1.5 regenerates and proves reproducible ObjectBox bindings with semantically/structurally invariant model schema/UIDs under G3; T3 tests pass on accepted generated output (D2).
- [x] 1.4 Stable-partition both `ContentSubmissionDateChip.date`/`.time` signatures in `lib/ui/content_submission/widgets/content_submission_date_chip.dart`, `_primaryActionButton` in `content_submission_progress_screen.dart` (same directory), the constructor in `lib/ui/gallery/widgets/_gallery_preview_modal_overlay_content.dart`, and constructor in `lib/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart` (10 diagnostics). Result: all five signatures retain defaults/super.key/initializers/callbacks and part boundaries; no State/lifecycle/call-site edits; T4 tests pass (D1/D5).
- [x] 1.5 Execute generator audit G0–G5 after the six input changes: run `dart run build_runner build --delete-conflicting-outputs` in the safe resolved environment, capture exit/output snapshots, compare preflight and classify every diff; verify G2 DTO bindings/keys/types/defaults/hooks/relation and decoder/representation contracts plus G3 ObjectBox schema/UID/relationship/bindings. Include only attributed contract-preserving generated output, preserving/excluding unrelated work. After final formatting snapshot accepted delivery inputs/outputs and repeat the standard workflow with fresh build state and identical resolution; compare all five outputs directly with the accepted versioned candidate. Result: two successful generation records, classified baseline diff, consumer/contract audit and zero second-run divergence under G4. Stop/document incompatible semantics, schema/UID drift or unexplained/non-reproducible differences for explicit decision (G5); no hand-edits or behavior changes to bypass the gate.

## 2. AppPulseEffect

- [x] 2.1 Reconfirm skeletonizer's resolved PaintingEffect has only final lowerBound/upperBound/reverse/duration and AppPulseEffect only final from/to/color; add only `@immutable` using its existing foundation import in `lib/ui/core/ui/skeletons/app_pulse_effect.dart`. Result: annotation diff has no constructor/assert/paint/lerp/equality/hash change; F1 bound omission remains recorded separately and unchanged (D3).
- [x] 2.2 Compare all runtime members byte-for-byte against preflight and inspect final analyzer entries for this class. Result: both baseline B occurrences disappear, no must_be_immutable or other new diagnostics, equality/hash implementation identical; no new runtime test solely for annotation metadata (D3/D10).

## 3. SyncViewModel

- [x] 3.1 Add `dart:async` import and wrap only the constructor's `sync.execute(false)` with `unawaited` in `lib/ui/sync/view_models/sync_view_model.dart`. Result: Future<void> matches SDK helper, isSyncRequired condition/false argument/immediate execution/Command ownership and all state/result/fatalError/notification/error-reporting code remain unchanged; no legacy migration (D4/D5).
- [x] 3.2 Run both T5 test files and audit constructor → execute → _sync → existing Command error/notification flow. Result: current auto-start/success/error/fatalError/no-op/forced/running presentation expectations pass and source diff confirms unchanged scheduling/reporting. If evidence exposes an uncovered risk, record the precise gap and justify only a deterministic focused case using existing support/required skills; otherwise add no test. No behavioral or lifecycle fix and no skips (D4/D10).

## 4. Final verification

- [x] 4.1 Run `dart format` with explicit paths for the 18 manually changed matrix files only. Result: formatter diff preserves D1–D6 with no mass formatting; complete/repeat task 1.5/G4 on final formatted inputs and accepted output bytes before final tests/analyzer. Generated outputs come from the standard generator, not manual formatting after the reproduction check; any later affected edit invalidates G4.
- [x] 4.2 Ensure T1–T5 explicit existing tests in design pass for final executable source and accepted generated outputs after G4; rerun affected gates if formatting/generation changed executable content or concerns remain. Result: command/exit/skip report for relevant gates, Pulse minimum verification and G2/G3 contract audit complementing reproducibility evidence; no weakened assertions or added skips (D2/D10).
- [x] 4.3 Run full `flutter test` after final formatting. Result: full-suite exit/outcome and existing skips recorded; investigate any failures and distinguish proven preexisting environment failures from regressions without claiming an unexecuted/failed check passed.
- [x] 4.4 Recapture `flutter analyze --no-pub` full output/exit and compare ledgers by exact rule/severity/message/file and diff-mapped positions. Result: all 76 audited targets (or explicitly reconciled fresh baseline) removed, all three target counts zero, no new identities, four warning identities preserved; 202 total/198 info used only as unchanged-baseline cross-check; red exit explained by preexisting excluded diagnostics (D7/D8).
- [x] 4.5 Run `git diff --check` and `git diff --cached --check` normally; audit staged/unstaged/untracked files against preflight, including artifact whitespace. Result: zero PR2-introduced issues/unclassified reports and preserved preexisting work; scope ledger distinguishes the original 18 manually editable production files, intentional attributed/reproducible generated outputs from G, OpenSpec artifacts, preexisting edits and excluded foreign files/drift. No options/CI/dependency/backend/schema/AGENTS.md/main-spec/PR1 archive changes (D2/D6/D9); an accepted generated diff is not itself a scope violation.
- [x] 4.6 Re-read proposal/design/tasks and map every target position plus D1–D10 to final diff/evidence; run `openspec validate resolve-flutter-analyzer-diagnostics-pr2 --strict --no-interactive` and status. Result: strict validation passes, specs remain skipped, no hidden out-of-scope task or artificial delta/main specs.
- [x] 4.7 Obtain independent adversarial review of final diff/evidence, resolve verified in-scope findings and deliver acceptance report with provenance, tests, analyzer identity comparison, both generation records, classified output diff/consumer audit, schema and final reproduction comparisons, whitespace/scope audit and limitations. Result: explicit acceptance against every design criterion or blockers; no inferred authority for commit/push/PR/merge/spec sync/archive. This is a future apply report, not a planning-time implementation claim.


## Apply verification report — 2026-10-14

### Baseline and ownership

- Apply explicitly authorized after final external adversarial approval. HEAD remains `1c64537d3fdae33a2ba6bee2fe7db32a580b691e`; initial branch `main`, final local branch `codex/resolve-flutter-analyzer-diagnostics-pr2`. Ancestry exit 0; no intervening commits. Initial status: only ` M AGENTS.md` and the untracked PR2 directory (the earlier planning ZIP was absent at apply preflight). No staged changes. Full staged/unstaged/untracked snapshots and hashes were captured before edits.
- Flutter 3.47.5 stable, framework 6a19cca564, Dart 3.13.4, OpenSpec 1.12.0. Resolved: very_good_analysis 11.0.0; command_it 9.5.2; skeletonizer 3.0.0; build_runner 2.15.1; dart_mappable runtime 4.10.0 / builder 4.8.0; ObjectBox/runtime Flutter libs/generator 5.3.2. Configuration, lockfile and actual package roots match planning; no dependency update.
- Before analyzer: exit 1, 278 diagnostics = 274 info + 4 warnings, zero errors. Targets exactly 73/2/1: no source, SDK or diagnostic drift. No nested AGENTS.md or competing ownership for these edits found.

### Implemented changes

- D1: 17 signatures in 16 files stable-partitioned, grouped domain 30 / DTO 16 / ObjectBox entity 17 / UI 10 diagnostics. Recorded every original/new signature and verified relative required/optional order. Reconstruction against the preflight source proves all other bytes in those files unchanged: fields, types, defaults, initializers, super forwarding, date/time mode, private method bodies, call sites and callbacks retained.
- D3: AppPulseEffect adds only @immutable using existing import; resolved PaintingEffect has only final inherited fields. All runtime members, assertions, equality/hash and lerp compare unchanged. Existing bound omission remains independent and untouched; no must_be_immutable introduced.
- D4: SyncViewModel adds dart:async and exactly unawaited(sync.execute(false)); inverse transformation reproduces the original file. Future<void> signature and empty SDK helper preserve immediate invocation, ownership, running/results/fatalError/notifications and existing legacy Command reporting. Command implementation unchanged; no migration or new test needed.
- Manual scope: the original 18 files only. Generated scope: the three DTO .mapper.dart files and lib/generated/objectbox.g.dart, copied byte-for-byte from generation; no hand edits. No production implementation deviation from the approved plan.

### Generator audit G0–G5

- G0: snapshotted all six inputs, five outputs, configuration, resolved package identity and preexisting work; inventoried 19 existing versioned generator/schema artifacts. Generated in `/tmp/moliseis-pr2-apply/gen1` and `gen2`, copies of actual final source including required local generator inputs, excluding Git/platform/backend/OpenSpec/harness directories and build caches. Each copied source file was verified against the checkout manifest; package_config/package_graph retained locked resolution. Source/config/lock hashes remained fixed. No secret-bearing contents were printed.
- G1: both isolated runs executed `dart run build_runner build --delete-conflicting-outputs` with the resolved Dart executable; each exit 0, each fresh build wrote 25 outputs. An earlier invocation from the wrong working directory was interrupted (exit 130); all versioned generated hashes were verified unchanged afterward and this attempt is not counted as generation evidence.
- Included/classified: three DTO mappers reorder getter/Field declarations, field-map entries and data.dec calls deterministically with the input partition. ObjectBox reorders parameter temporary reads and named arguments for Media/Event/Place. Canonical structural comparisons prove exact per-field definitions, key/type/nullability/default/hook bindings and per-parameter expressions are unchanged; remaining generated metadata, relationship attachment/backlinks and other entity code are byte-identical after removing only those order permutations.
- G2: relation resolver/field hooks are unchanged and have no cross-field state; Keep/Clear/Assign, customized Media description key, snake_case, nullable/default and category conversion definitions remain identical. T2/T3 validate decoding/mapping contracts. Generated map/JSON/stringify order follows the new field order and is not claimed byte-identical to baseline; current consumers have no verified hashing/snapshot/string-equality order dependency, and PATCH builders construct maps independently. For malformed rows with several bad fields the first decoder exception can change; no repository contract/tests for that precedence were found, and per-field failures/reporting remain unchanged. No material contractual change identified.
- G3: objectbox-model.json is byte-for-byte and parsed-structure identical, including entity/property IDs/UIDs/types/indexes/relations/backlinks/metadata. Constructor bindings and buffer offsets/read expressions are identical per parameter. T3 real-store/previous-store tests pass; no schema migration.
- Excluded/classified: only lib/config/env/env.g.dart also differed in each isolated run. Envied obfuscation uses Random.secure() without a fixed seed; inputs did not change. This unrelated randomized output was never copied into the checkout. Other output hashes unchanged; no unexplained drift remains.
- G4: after final formatting and integrating the four reviewed outputs, recorded the accepted checkout candidate. Gen2 started without .dart_tool/build, actually regenerated outputs and matched all five scoped output files directly to that candidate by bytes/SHA-256; all 18 manual-source and relevant config/lock hashes also match. Zero additional PR2 differences. No affected source/output changed afterward, so reproduction evidence remains valid. G5 stop conditions did not occur.

### Test verification

All commands ran on final formatted source and accepted generated output. Targeted commands used flutter test --no-pub --reporter json with exactly the explicit T1–T5 paths from design:

| Group | Passed | Failed | Skipped | Exit |
| --- | ---: | ---: | ---: | ---: |
| T1 | 20 | 0 | 0 | 0 |
| T2 | 51 | 0 | 0 | 0 |
| T3 | 41 | 0 | 0 | 0 |
| T4 | 85 | 0 | 0 | 0 |
| T5 | 12 | 0 | 0 | 0 |

Full `flutter test --no-pub --reporter json`: exit 0, 2213 passed / 0 failed / 6 skipped. All test files and existing skip declarations are byte-identical to preflight; no assertions weakened or skips added.

Existing skipped cases recorded by the runner:

- edited requests survive local publication, cache and Rome rendering
- real authenticated Dart preview/apply preserves PostgreSQL microsecond tokens, rejects drift and retries a lost committed response
- A upstream-like captures current StateError after dispose; checks notifier safety
- B runAsync captures current StateError after dispose; checks notifier safety
- E Molise reporting captures current StateError after dispose; checks notifier safety
- NAV-01 [upstream #188018] inactive Post branch must not consume Map root Back

### Analyzer, scope and readiness

| Target rule | Before | After |
| --- | ---: | ---: |
| always_put_required_named_parameters_first | 73 | 0 |
| avoid_equals_and_hash_code_on_mutable_classes | 2 | 0 |
| discarded_futures | 1 | 0 |

Final flutter analyze --no-pub exit 1: 202 diagnostics = 198 info + 4 warnings, zero errors. All 202 residual identities match rule/severity/exact message/file and diff-mapped positions; no new or unmatched diagnostic. Two legacy deprecations in SyncViewModel move only from 13:12 to 15:12 and 35:8 to 37:8 due to the import. All four warning identities unchanged. Exit 1 is explained exclusively by preexisting out-of-scope diagnostics; options/suppressions/CI untouched.

Both git diff --check and git diff --cached --check exit 0 with empty reports; untracked artifact whitespace audited separately. Scope/hash audit accounts for exactly 18 manual files, four accepted generated files and this tasks artifact relative to apply preflight. Every other tracked/untracked preexisting file hash is preserved, including AGENTS.md, OpenSpec metadata/proposal/design and test files. No backend, main-spec, archive, dependency, analyzer/CI or schema changes. No staged work, commit, push, PR, merge, spec sync or archive.

OpenSpec strict/no-interactive validation passes; status recognizes specs skipped. All 20 tasks completed against acceptance evidence; historical planning/remediation sections remain historical. Independent adversarial reviewer reconstructed all manual edits, checked generated reproducibility/schema/ownership and final tests/analyzer evidence, and reported no material finding. Coverage limits remain those in design: these tests do not claim exhaustive runtime proof, complemented by exact source/contract comparisons. No unresolved blocker or verification limitation remains.

Acceptance: IMPLEMENTED — READY FOR EXTERNAL ADVERSARIAL REVIEW. No authority for commit or merge is inferred. Detailed raw command logs, source/output snapshots, manifests, canonical generated audit, diagnostic position comparison and test JSON summaries are retained in `/tmp/moliseis-pr2-apply/` (ephemeral); this report preserves the verified outcomes.
