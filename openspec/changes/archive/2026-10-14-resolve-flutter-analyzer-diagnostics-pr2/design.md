## Context — repository audit and baseline

See proposal.md for motivation, exact HEAD, versions and non-goals. Audit date 2026-10-14; baseline equals `1c64537d3fdae33a2ba6bee2fe7db32a580b691e` on `main`. `git merge-base --is-ancestor` exited 0; `git log baseline..HEAD` is empty. Initial status: only ` M AGENTS.md`, no staged/untracked files. Its SHA-256 is `33b86e7b0a44df3ad1616231363ac7577d09d19466800287c70d0adc67e32aef`. Preexisting unstaged/cached diffs were retained outside source; both initial whitespace checks exit 0. No target source differs from HEAD. Repository AGENTS.md applies; discovery found no nested AGENTS.md in the affected source/test/OpenSpec paths. PR1's four archived artifacts were read and remain untouched.

The new change directory did not exist before creation. `openspec list --json` showed `improve-admin-submission-editor-workflow` (0/25), `harden-geo-map-semantic-state` (34/34), and `optimize-content-sync-delta-retrieval` (21/21). Inspection found adjacent admin-model, GeoMap and sync domains but no competing task for these parameter-order/annotation/unawaited edits. These changes confer no authority to modify their artifacts or extend PR2. Refresh ownership at apply; changed overlap requires reconciliation, not silently combining work.

`analysis_options.yaml` includes very_good_analysis defaults, `todo: info`, excludes **.g.dart/**.init.dart/**.mapper.dart and platform/build paths, enables existing const preferences and disables public_member_api_docs. pubspec and lockfile were read; `.dart_tool/package_config.json` resolves packages into the inspected local pub cache. Exact versions are in proposal.md, including the intentional distinction between dart_mappable runtime 4.10.0 and builder 4.8.0. Do not update either.

Initial Flutter commands were blocked while writing external SDK cache markers. The authorized rerun completed `flutter --version`, `dart --version` and `flutter analyze --no-pub`; analysis exited 1 because of diagnostics, not tool failure. Full analyzer stdout/stderr is retained at `/tmp/moliseis-pr2-analyze-before.log`, parsed ledger at `/tmp/moliseis-pr2-ledger.json`. These paths are ephemeral; the inventory below is durable and apply must recapture full evidence and exit status before edits. Tests were inspected, not run during planning. No implementation result is claimed.

## Goals / Non-Goals

Remove all currently present occurrences of the three target rules with semantic neutrality. Preserve all public parameter names/types/requiredness/defaults/nullability, field layout, named call sites, superclass forwarding, initializer expressions, generated mapping and lifecycle. The source declaration order will change but the callable API contract will not. All exclusions in proposal.md apply; there is no migration, deployment, main-spec change or authorized apply in this planning delivery.

## Diagnostic distribution

Observed 278 = 0 errors + 4 warnings + 274 info; historical target counts match without drift.

| Rule | Severity | Count |
| --- | --- | ---: |
| always_put_required_named_parameters_first | info | 73 |
| async_return_with_no_await | info | 57 |
| avoid_positional_boolean_parameters | info | 15 |
| deprecated_member_use_from_same_package | info | 125 |
| unawaited_return_in_try_block | warning | 1 |
| experimental_member_use | warning | 3 |
| avoid_equals_and_hash_code_on_mutable_classes | info | 2 |
| avoid_catching_errors | info | 1 |
| discarded_futures | info | 1 |

After removal of 76 target info, projected 202 = 4 warnings + 198 info. Counts are cross-checks only, never permission to force a result or ignore identity changes.

Warning identities to preserve:

- `unawaited_return_in_try_block`: `lib/ui/content_submission/view_models/content_submission_view_model.dart:799:7`.
- `experimental_member_use`: `lib/ui/content_submission/widgets/content_submission_description_form_field.dart:150:9`, `150:26`, `150:47`.

## Complete diagnostic matrix

All rows are info. Positions are pre-edit line:column. A = `always_put_required_named_parameters_first`; B = `avoid_equals_and_hash_code_on_mutable_classes`; C = `discarded_futures`. Each listed position is a separate occurrence, not a count of signatures. There are 73 A, 2 B and 1 C, across 18 files.

| Rule | File | Occurrences / positions | Planned modification | Verification / task |
| --- | --- | --- | --- | --- |
| A | `lib/data/data-sources/event_entity.dart` | 5: 18:19, 20:19, 21:19, 22:19, 23:19 | Stable partition of named parameters only (D1) | Entity tests T3; generator audit G; 1.3 |
| A | `lib/data/data-sources/media_entity.dart` | 7: 14:19, 15:19, 16:19, 19:19, 20:19, 21:19, 22:19 | Stable partition of named parameters only (D1) | Entity tests T3; generator audit G; 1.3 |
| A | `lib/data/data-sources/place_entity.dart` | 5: 15:19, 17:19, 18:19, 19:19, 20:19 | Stable partition of named parameters only (D1) | Entity tests T3; generator audit G; 1.3 |
| A | `lib/data/dtos/event_dto.dart` | 6: 26:19, 27:19, 28:19, 29:19, 30:19, 31:19 | Stable partition of named parameters only (D1) | DTO tests T2; generator audit G; 1.2 |
| A | `lib/data/dtos/media_dto.dart` | 5: 24:19, 25:19, 26:19, 29:19, 30:19 | Stable partition of named parameters only (D1) | DTO tests T2; generator audit G; 1.2 |
| A | `lib/data/dtos/place_dto.dart` | 5: 26:19, 27:19, 28:19, 30:19, 31:19 | Stable partition of named parameters only (D1) | DTO tests T2; generator audit G; 1.2 |
| A | `lib/domain/models/admin_submission.dart` | 6: 27:19, 28:19, 29:19, 30:19, 31:19, 32:19 | Stable partition of named parameters only (D1) | Domain tests T1; signature/initializer audit; 1.1 |
| A | `lib/domain/models/content_base.dart` | 4: 67:19, 68:19, 69:19, 70:19 | Stable partition of named parameters only (D1) | Domain tests T1; signature/initializer audit; 1.1 |
| A | `lib/domain/models/content_submission.dart` | 2: 22:19, 23:19 | Stable partition of named parameters only (D1) | Domain tests T1; signature/initializer audit; 1.1 |
| A | `lib/domain/models/event.dart` | 6: 14:20, 15:20, 16:20, 17:20, 18:20, 19:19 | Stable partition of named parameters only (D1) | Domain tests T1; signature/initializer audit; 1.1 |
| A | `lib/domain/models/media.dart` | 7: 15:19, 16:19, 17:19, 18:19, 19:19, 20:19, 21:19 | Stable partition of named parameters only (D1) | Domain tests T1; signature/initializer audit; 1.1 |
| A | `lib/domain/models/place.dart` | 5: 14:20, 15:20, 16:20, 17:20, 18:20 | Stable partition of named parameters only (D1) | Domain tests T1; signature/initializer audit; 1.1 |
| A | `lib/ui/content_submission/widgets/content_submission_date_chip.dart` | 4: 17:19, 19:19, 29:19, 31:19 | Stable partition of named parameters only (D1) | UI tests T4; callback/part audit; 1.4 |
| A | `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 1: 165:21 | Stable partition of named parameters only (D1) | UI tests T4; callback/part audit; 1.4 |
| B | `lib/ui/core/ui/skeletons/app_pulse_effect.dart` | 2: 52:3, 62:3 | Add @immutable only (existing import) | Inherited final fields, unchanged equality/hash source, analyzer; 2.1–2.2 |
| A | `lib/ui/gallery/widgets/_gallery_preview_modal_overlay_content.dart` | 3: 12:19, 14:19, 15:19 | Stable partition of named parameters only (D1) | UI tests T4; callback/part audit; 1.4 |
| A | `lib/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart` | 2: 12:19, 14:19 | Stable partition of named parameters only (D1) | UI tests T4; callback/part audit; 1.4 |
| C | `lib/ui/sync/view_models/sync_view_model.dart` | 1: 16:12 | Import dart:async; unawaited around existing call only | Future<void>, T5, unchanged error/reporting flow; 3.1–3.2 |

## Decisions D1–D10 and invariants

### D1 — Stable partition

For each affected named signature, put required parameters before optional ones, retaining each group's original relative order. Preserve exact names, types, defaults, nullability, `this.*`/`super.*`, const status, assertions, bodies and initializer lists. Never reorder fields or correctly named call sites. This is narrower and easier to audit than sorting alphabetically or applying bulk fixes.

Inspection confirms ordinary constructors in domain/DTO/entity files, superclass forwarding in Event/Place and named generative `.date` / `.time` constructors in ContentSubmissionDateChip. The chip constructors are not redirecting constructors: each retains its `_mode` and null-field initializer list. The progress-screen target is the private `_primaryActionButton` method, not a constructor: move required `child` ahead of optional `onPressed`, preserving required `colorScheme` first. Gallery content is a part of `gallery_preview_modal_overlay.dart`; preserve library/part boundaries and imports. No target redirecting constructor was found. Preserve AdminSubmission/ContentSubmission descriptionDelta freezing and assets unmodifiable initializers. Preserve entity category validation and relationship defaults.

### D2 — Generated code and persistence (audit G)

**Compatibility and reproducibility are separate requirements.** Existing named constructor calls can remain callable after D1 while no longer matching generator output from the new sources. AGENTS.md requires the standard workflow when generator inputs change. The following gate is mandatory for future apply, not executed during this planning remediation.

**G0 — Inputs, evidence and safe environment.** Scope is the six inputs `lib/data/data-sources/{event,media,place}_entity.dart` and `lib/data/dtos/{event,media,place}_dto.dart`; outputs are `lib/data/dtos/generated/{event_dto,media_dto,place_dto}.mapper.dart`, `lib/generated/objectbox.g.dart` and the persistence invariant `lib/generated/objectbox-model.json`. Resolve from the unchanged lockfile/package config: build_runner 2.15.1, dart_mappable_builder 4.8.0 with runtime 4.10.0, objectbox_generator/runtime 5.3.2. Keep SDK, build configuration and all transitive dependencies fixed; no upgrades or generator customization.

Before generation snapshot the six inputs, five versioned outputs, relevant configuration, resolved dependency identity, and staged/unstaged/untracked ownership; retain content copies and hashes outside source. Inventory other versioned outputs the standard workflow may touch so their changes can be attributed, without broadening this gate into a project-wide generator cleanup. Never expose Envied secrets in logs/diffs/reports. If generation could overwrite preexisting work, use an isolated copy with a documented source manifest representing final PR2 inputs and their actual dependencies. A bare HEAD checkout is insufficient when final source includes authorized edits or relevant local changes. Preserve and identify unrelated local edits; do not silently fold them into PR2. Record what is copied/excluded and verify the manifest against the intended final source. Do not copy stale build caches; retain the locked dependency resolution. No reset, restore or clean, and no generator writes into user-owned dirty outputs. An unsafe or unfaithful environment blocks the gate until resolved.

**G1 — Required generation and diff classification.** After the six source changes, run in that safe environment:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Capture command, environment/source manifest, exit code, output inventory and before/after snapshots. A failed command is not a passed gate. Compare the entire touched-output inventory with preflight; classify each hunk as (a) deterministic consequence of authorized parameter ordering, (b) semantically relevant change requiring verification, (c) unrelated drift, or (d) unexplained/non-reproducible difference. Categories may overlap until investigation resolves them. Every included difference needs a demonstrated input-to-output relationship; do not automatically accept generator output. If attribution requires it, generate the pre-PR2 source snapshot in a separate equivalent environment to distinguish old drift from PR2 effects. Keep unrelated Envied/other-model output outside PR2 and preserve original user files; isolate generation rather than deleting or overwriting unrelated differences in place.

Local generator inspection establishes order sensitivity, not an observed regeneration result: ObjectBox 5.3.2 `lib/src/code_chunks.dart` iterates `constructorParams`, emits temporary values and named constructor calls, then attaches relationships; `entity_resolver.dart` collects formal parameters. dart_mappable_builder 4.8.0 `elements/class/mixins/param_elements_mixin.dart` walks constructor formal parameters; `generators/mixins/decoding_mixin.dart` emits ordered `data.dec(...)`; `elements/class/class_mapper_element.dart` starts its field list with those params; `generators/extensions/fields_extension.dart` emits that ordered field map. The ObjectBox resolver collects properties from class fields separately from constructor parameters, so constructor ordering is not itself evidence of a schema change. Verify actual diffs for all six classes during apply; do not presume identical changes for every class.

**G2 — DTO contracts and representation.** For each regenerated DTO mapper compare field-to-named-parameter binding, JSON keys (snake_case and MediaDto title key `description`), types/nullability/defaults, ContentCategory conversion, relation hooks and Keep/Clear/Assign semantics. Audit changed decoder evaluation order, including failures/hook side effects; data equivalence on valid rows alone is insufficient if contractual error behavior changes. Verify the generated field-map, JSON and stringify ordering and inspect repository consumers for dependencies on that order (hashing/signatures, serialized-string comparisons, snapshots or persisted representation contracts).

Read-only P1 audit found runtime dart_mappable 4.10.0 `lib/src/mappers/interface_mapper.dart` encodes fields in their supplied order and JSON via jsonEncode of that map. Searches across lib/test found no concrete consumer hashing, snapshotting or comparing the generated EventDto/MediaDto/PlaceDto JSON/string representation by order; `lib/data/core/{event,media,place}_dto_patch_encoding.dart` constructs PATCH maps explicitly, independently of generated field order. This is current source evidence, not proof about unknown external consumers or a substitute for reviewing the actual generated diff. Recheck affected consumers at apply.

Semantic equivalence of data means identical keys, values, null/default and relation meaning after decoding/encoding; it is distinct from byte-for-byte equivalence of a serialized string or toString result. JSON object-property order is not assumed contractual. Controlled order-only output changes are allowed when fields are semantically unordered and the consumer audit finds no concrete order dependency; document evidence per changed representation. A verified representation-order contract or incompatible decoder behavior is a material risk and stops affected execution. Do not change application behavior or invent generator configuration to preserve an old order. Use T2/T3 tests plus the targeted source/consumer diff audit; add a deterministic focused case only if a concrete uncovered risk justifies it under D10.

**G3 — ObjectBox invariants.** Verify entity IDs/UIDs, property IDs/UIDs/types, indexes, ToOne/ToMany relationships, backlinks, persistence metadata and every constructor binding. Inspect generated temporary reads and relationship attachment as well as named calls. `objectbox-model.json` must remain semantically and structurally identical (all keys/values, array order and schema/UID metadata); retain its hash and parsed structural comparison, and classify even formatting-only changes rather than treating them as a schema migration. Unexpected schema/ID/UID changes block apply until an explicit decision. No persistence migration is authorized. Run T3 including real-store/previous-store coverage against the final accepted outputs.

**G4 — Inclusion and final reproduction.** Integrate only attributed, contract-preserving generated changes from the affected outputs together with their inputs; no manual edits to generated code. Keep preexisting and unrelated differences separate in the evidence and outside delivery. After the final input formatting and acceptance of generated outputs, snapshot the accepted final sources and versioned outputs as the candidate to reproduce. Run the same standard command again with the same resolved environment; use a fresh isolated build state without a reused incremental build cache so the check actually regenerates the affected outputs. Compare hashes/content of all five scoped outputs with the accepted candidate and verify source/config/lock manifests remained identical. If verification is isolated, compare directly with the versioned candidate intended for delivery, not only two temporary copies. Record both generation runs and their exit codes, the accepted baseline-to-final diff, preexisting/foreign diffs and the second-run comparison separately. Success requires no additional PR2-attributable differences and no unexplained divergence between final inputs and outputs; a cached no-op or merely passing analyze/tests is insufficient. Later input/output formatting or edits invalidate this evidence and require regeneration/reverification before final tests/analyzer.

**G5 — Anomalies and stop rule.** Unexplained/non-reproducible diffs, unexplained source/environment drift, schema/UID changes or incompatible contractual semantics block the affected implementation. Document the concrete contradiction and request an explicit decision before widening scope. Never silently include incompatible output, hand-edit generated files, retain stale compatible output to evade reproduction, or alter application behavior to make the gate pass. Preserving contracts takes precedence over reaching zero target diagnostics. No code generation or generated-output modification is authorized during this remediation.

### D3 — Declarative immutability

skeletonizer 3.0.0 `lib/src/effects/painting_effect.dart` defines only four final instance fields: lowerBound, upperBound (double), reverse (bool), duration (Duration), a const constructor and abstract paint/lerp methods. It has no mutable inherited state. AppPulseEffect adds only final Color? from/to/color. The existing `package:flutter/foundation.dart` import supplies `immutable`; add the annotation only. No constructor, assert, createPaint, lerp, == or hashCode edits. This accurately declares existing immutability and should remove B without `must_be_immutable`; final analyzer evidence must confirm that prediction. Removing equality/hash or rewriting the base class is unnecessary.

Independent finding F1: two otherwise equal effects with differing lowerBound/upperBound currently compare equal and hash equally although bounds configure animation. This is a verified omission, not proof of a reported user-visible defect; current usage in `skeleton_content_sliver_grid.dart` supplies defaults. It does not prevent declaring all fields immutable. Record separately; do not add bound comparisons, alter lerp or tests that impose new equality requirements in PR2.

### D4 — Explicit fire-and-forget

`lib/utils/command.dart` Command1.execute(A) returns Future<void>, awaiting the existing `_execute` implementation. The SDK's async/future.dart defines `void unawaited(Future<void>? future) {}`: it does not await, schedule, attach handlers or swallow errors. Add `import 'dart:async';` and wrap only `sync.execute(false)` within the unchanged isSyncRequired branch. The call is still evaluated immediately during construction after `sync = Command1(_sync)`. Awaiting, deferring into another callback, changing ownership or migrating commands would change intent and is excluded.

Keep running admission, completed/error/result state, fatalError classification, listener notification order and error propagation/reporting unchanged. Existing legacy `_execute` captures unexpected Object, converts it to Result.error and reports original error via FlutterError.reportError, with final notification; this existing contract must not be refactored. D4 does not add a new legacy consumer/reference; it modifies an existing call, as permitted by AGENTS.md. No lifecycle/dispose repair belongs here.

### D5 — Semantic neutrality

No contractual runtime behavior, callback order, lifecycle, serialization, persistence, navigation, error handling or API change. For generated representations, D2 distinguishes data equivalence from textual ordering and requires preservation of every verified representation contract. Source declaration reorder preserves named binding; leave evaluation expressions at all call sites unchanged. Paint/equality bodies and sync orchestration remain byte-identical except the precise annotation/import/wrapper described above. A semantic contradiction blocks affected execution rather than authorizing a redesign.

### D6 — Minimal diff

Limit manual production changes to the 18 matrix files and required formatter consequences; allow only the attributed, contract-preserving, reproducible generated outputs from D2 in addition. No abstractions, packages, naming changes, automatic broad lint fixes, unrelated refactors or mass formatting. Generated changes must satisfy D2; compatibility alone does not justify retaining stale output or including unrelated churn. Do not alter user work to obtain a clean diff.

### D7 — Diagnostic identity comparison

Compare before/after multisets including rule, severity, exact message, file, line and column. Use the actual source diff to map positions of unchanged occurrences in edited files. Aggregate counts or matching by rule/file alone cannot prove absence of new diagnostics; strategy below is mandatory.

### D8 — Analyzer intentionally red

Do not change analysis_options.yaml, very_good_analysis rules, exclusions, dependency versions, CI workflows or required checks. No suppressions, ignore_for_file or lint disables. PR2 does not enable analyzer as merge gate. Nonzero analyzer/CI status is acceptable only when attributable to preexisting excluded diagnostics, never new diagnostics or unexplained tool/build failures.

### D9 — Preserve preexisting work

Snapshot staged/unstaged diffs and all untracked paths at authoring and subsequent apply. AGENTS.md is unrelated and remains untouched. No reset/restore/clean or destructive cleanup. Attribute each diff to PR2 or known preexisting work, including same-file overlaps; investigate uncertain provenance. The later cohesive PR must exclude unrelated modifications. This planning request forbids commit/push/PR/merge/sync/archive.

### D10 — Risk-proportionate tests

Use existing contract tests and compilation evidence, with source-level invariants as complementary evidence. Do not add tests solely because a lint disappears. No new test is currently justified solely by the manual edits: parameter changes retain named binding, annotation has no runtime code, unawaited has an empty SDK implementation and existing sync tests cover terminal behavior. Generator gate G additionally audits changed decoder/representation ordering and reproducibility; a concrete coverage gap is assessed under the following rule. If fresh evidence reveals an actual uncovered risk, describe the gap and add only a deterministic focused case within existing support conventions; a behavioral fix requires separate authorization. Do not weaken assertions or add skips.

## Test strategy and coverage limits

These paths exist and their relevant source/tests were inspected. All commands below are for future authorized apply; none has passed merely by being listed. Run individual files for the affected group first, then full `flutter test` after formatting. Flutter test compiles exercised paths; the final analyzer must also show no compile/type diagnostics in untouched consumers.

- **T1 domain:** `test/domain/models/content_base_test.dart`, `admin_submission_models_test.dart`, `content_submission_test.dart`, `all_day_models_test.dart` (all under `test/domain/models/`). Covers domain equality/immutable snapshots and event/date semantics; field/default/initializer equivalence still requires source review.
- **T2 DTO:** `test/data/mappers/event_dto_mapper_test.dart`, `media_dto_mapper_test.dart`, `canonical_dto_lifecycle_test.dart` (same mapper directory), plus `test/data/core/relation_update_hook_test.dart`. Canonical lifecycle exercises Event/Place/Media create/merge and nullable/tombstone contracts; the relation-hook file directly exercises generated decoding for all three DTOs and PATCH Keep/Clear/Assign encoding; Event/Media mapper tests additionally exercise generated decoding; there is no dedicated place_dto_mapper_test.dart in this checkout. Inspect generated fields and caller binding in addition to running these tests; map equality alone does not prove JSON insertion order unchanged; use D2/G2 to distinguish data equivalence from any verified textual-order contract and G4 for reproduction evidence.
- **T3 persistence/entity:** `test/data/mappers/event_entity_mapper_test.dart`, `media_entity_mapper_test.dart`, `place_entity_mapper_test.dart`; `test/domain/use_cases/sync_use_case_objectbox_test.dart`; `test/data/content_sync_previous_store_test.dart`. These cover entity/domain mapping, real ObjectBox relationships/sync and previous-store compatibility. Compare current model JSON and generated bindings directly; tests cannot authorize a schema change.
- **T4 UI:** `test/ui/content_submission/widgets/content_submission_date_chip_test.dart`, `content_submission_progress_screen_test.dart` (same directory); `test/ui/gallery/widgets/gallery_preview_screen_test.dart`; `test/ui/geo_map/widgets/geo_map_screen_test.dart`. Existing date/time mode, progress, gallery and map coverage complements unchanged initializer/callback/part review. These do not claim exhaustive direct testing of every private gallery overlay or animated search callback; declaration-only edits do not justify new UI fixtures.
- **T5 sync:** `test/ui/sync/view_models/sync_view_model_test.dart` covers no-auto-sync, automatic success, forced/no-op, recoverable error with/without prior cache and fatalError; `test/ui/sync/widgets/sync_screen_test.dart` covers running presentation via a gated repository and idle presentation. Existing automatic cases wait on pumpEventQueue rather than a new timer. Notification order and unexpected-error reporting are preserved by unchanged Command source plus empty unawaited source, not claimed directly asserted by these tests. No new scheduling/delay or Command tests needed.
- **Pulse minimum verification:** no AppPulseEffect test exists (search confirmed). Compare constructor/assert/createPaint/lerp/equality/hash source before/after exactly; inspect inherited final fields; final analyzer must remove both B and introduce no must_be_immutable. This is proportionate for annotation-only metadata. Equality/hash behavior remains identical by unchanged implementation; no new runtime test or golden is required.

Execute `flutter test <each explicit file above>` for relevant groups (batch explicit paths if useful), then `flutter test`. Record command, exit status, failures and existing skips. Investigate failures; do not claim readiness with unresolved change-induced failures or hide failures with skips. Preexisting environment failures are documented limitations, not a PASS. Before any new/modified Dart test, load dart-add-unit-test and molise-is-test-support-reuse, plus flutter-add-widget-test where applicable and molise-is-objectbox-test-store for persistence tests. Before editing widget State/callbacks load molise-is-async-mounted-context-safety; such changes beyond a parameter declaration are not currently planned. Apply the static-analysis skill for implementation verification. No test/support infrastructure is to be invented here.

## Diagnostic comparison strategy

Recapture full stdout/stderr and exit code with `flutter analyze --no-pub` before editing and after final formatting, keeping SDK/dependencies/options constant. Parse rows `severity • message • file:line:column • rule` into a ledger without dropping message or positions, plus counts by rule/severity. Save raw logs and ledgers outside source. Account for all 76 positions in the matrix, adjusting only for documented baseline drift.

Compare unchanged files at exact identity/position. For changed files map unchanged source through git diff hunks, including column movement from import/parameter changes; inspect every unmatched entry. Match the same source occurrence, not a different diagnostic with the same rule. All target rules must reach zero; all residual identities (including four warnings and any moved legacy deprecations) must be preserved under mapping, with no new unmatched post-change identity. Explain deletions outside targets too. Any new diagnostic, even one offset by a removed diagnostic, blocks completion pending investigation. Do not remove out-of-scope diagnostics to force 202. Document and reconcile HEAD/SDK/worktree/count drift before implementation; unexplained or material conflict blocks affected work.

## Diff and whitespace audit

At apply preflight capture status, HEAD/branch, staged/unstaged diffs, untracked inventory, and both `git diff --check` / `git diff --cached --check` outputs and exit codes outside source. Repeat at delivery normally, without filtering reports to hide unrelated issues. For each report attribute source occurrence against preflight even if line numbers/staging moved. PR2-introduced whitespace is blocking; untouched preexisting problems can be documented; uncertain origin must be resolved. Inspect change-authored untracked files separately because ordinary git diff omits them. Use scoped `git diff --no-index /dev/null <artifact>` (expected exit 1 for nonempty new file) or equivalent read-only inspection for each new artifact, and separate artifact whitespace checking. Format only explicit changed Dart paths using dart format, never lib/ or test/ wholesale. Check formatter diff preserves required-first stable order and every invariant. Separate the 18 manually editable files, accepted generated outputs under G, OpenSpec artifacts, preserved preexisting edits and excluded foreign files in the final scope ledger. The reproduction comparison must use final formatted source and accepted output bytes; do not manually reformat generated output after G4 without repeating that gate.

## Risks / Trade-offs

- Required/optional or relative order accidentally changed → compare each full signature, not just flagged lines; preserve `super.*`, named generative initializers and the private method; unchanged named callers compile through tests/analyzer.
- Stale or semantically changed generated output → mandatory generation, classified diff/consumer audit G, T2/T3 and fresh second-generation comparison; accept only demonstrated contract-preserving differences, stop on schema/UID, incompatible or unexplained drift.
- Annotation hides equality omission → F1 remains independent, unchanged and nonblocking; verify no must_be_immutable.
- Fire-and-forget silently becomes awaited/deferred or absorbs errors → SDK signature/body and legacy Command source plus T5 verify the precise wrapper; do not touch orchestration.
- Limited test coverage or aggregate counts conceal regression → minimal diff/source audit and identity ledger supplement tests; no claims of exhaustive runtime proof.
- Adjacent OpenSpec work or user AGENTS.md edit is accidentally bundled → refresh ownership and compare full preflight snapshots; preserve unrelated artifacts.

## Acceptance criteria

1. Zero remaining diagnostics in A/B/C, every baseline occurrence accounted for; no new diagnostic identities. At unchanged baseline expected 202/198 info, four preserved warnings and zero errors; analyzer exit remains nonzero solely for existing excluded diagnostics.
2. D1–D6 invariants hold for all 18 manually edited files and D2 for included generated output: unchanged named call sites/fields/defaults/nullability, DTO/entity mapping/persistence and painting/equality/hash/sync/error/lifecycle contracts. Representations preserve semantic data; byte-for-byte/order equality is required wherever the consumer audit verifies a representation contract, not universally assumed.
3. The standard generation workflow ran successfully on the final six inputs with unchanged resolved dependencies; source/config/output snapshots, command logs and a per-hunk classification prove every included generated diff is caused by authorized inputs and preserves G2/G3 contracts. Compatible old outputs alone are insufficient.
4. Accepted versioned outputs match a subsequent fresh generation in the same resolved environment (G4), with manifests/hashes/content comparisons and exit codes proving no additional PR2-attributable or unexplained differences. Intentional accepted baseline diffs and unrelated preexisting drift are separately identified; no drift is silently incorporated.
5. `objectbox-model.json` is semantically and structurally invariant against preflight, with no schema/entity/property ID/UID/type/index/relation/backlink/metadata changes; recorded structural comparison and T3 persistence evidence substantiate this. Unexpected changes block apply; no migration is permitted.
6. All required T1–T5 tests and full flutter test pass against final accepted source/generated outputs, with existing skips unchanged. Failures/environment limitations must be reported and cannot be called successful acceptance; no added skips or weakened assertions. G2/G4 evidence complements tests.
7. Explicit-file formatting, unstaged/cached whitespace checks and untracked audit complete: zero PR2-introduced problems, no unattributed reports. Scope ledger separates manual production edits, allowed generated diffs, planning artifacts, preserved preexisting work and excluded foreign output. All preexisting work remains intact and no unrelated drift enters delivery.
8. Proposal/design/tasks coherent, every target and D1–D10 mapped, strict OpenSpec validation passes and status reports specs skipped; no delta/main specs or archive edits. Any incompatible semantic or unexplained reproduction issue is an explicit blocker rather than an acceptance waiver.

## Subsequent apply, readiness and archive boundaries

Planning readiness means complete artifacts, actual-source evidence, successful strict validation and independent internal review with verified findings resolved. Final planning status is only READY FOR ADVERSARIAL REVIEW, never READY FOR APPLY. External adversarial review plus explicit user authorization are required before implementation. All checklist items stay unchecked during authoring, including future preflight reruns; planning audit is evidence above, not execution of an apply task.

Apply must first refresh baseline/worktree/ownership, SDK/dependencies, instructions and all diagnostic identities. Material contradictions return to planning/review; do not broaden scope or silently redesign. Use a later implementation branch under repository workflow; no direct push to main. This plan does not authorize commit/push/PR/merge. No runtime deployment or migration step is needed. If later rollback is required, reverse only PR2-authored changes, preserving unrelated work.

Implementation review readiness additionally requires acceptance evidence for the final source and an independent adversarial diff review; list all limitations. Subsequent archive requires separately authorized completion/integration and verified checklist/evidence, with skip_specs honored and no main-spec sync/change. Do not archive, sync or merge as part of this plan or infer authority from task completion.

## Original planning verification report — 2026-10-14 (before P1 remediation)

Historical evidence only: the subsequent external P1 finding supersedes the original generated-output/readiness assessment below. Current D2 and acceptance criteria govern; the original internal review did not establish reproducibility.

- Re-read proposal/design/tasks together; automated inventory audit accounts for all 76 raw analyzer target positions in the 18-row matrix and their task groups. D1–D10 present; 20 tasks, all unchecked, distributed 4/5/2/2/7 across phases 0–4. All 19 cited existing test paths verified; none run during planning.
- `openspec validate resolve-flutter-analyzer-diagnostics-pr2 --strict --no-interactive` passed (exit 0); CLI status reports proposal/design/tasks done, specs skipped. This reflects artifact completeness only, not implementation authority or completion.
- Independent reviewer inspected final artifacts, source, generator behavior, test references and raw diagnostic ledger: no material findings. Confirmed precise private-method/named-generative distinctions, inherited immutability and unchanged legacy error flow. Review did not implement fixes or execute Flutter tests. F1 remains independent/nonblocking.
- Both git whitespace checks pass (exit 0). Separate four-artifact whitespace and scoped new-file diff audit found no introduced problems. Current staged/unstaged tracked diffs compare byte-for-byte with preflight; AGENTS.md hash unchanged. Only this four-file directory was authored; production/tests/generated/main specs/PR1 archive unchanged.
- No commit, push, PR, merge, implementation, spec sync or archive performed. No unresolved planning blocker identified. Status: READY FOR ADVERSARIAL REVIEW; external review and explicit authorization still required before apply.

## P1 document remediation verification — 2026-10-14

Remediation preflight: HEAD `1c64537d3fdae33a2ba6bee2fe7db32a580b691e`, branch `main`; existing status was ` M AGENTS.md`, untracked PR2 directory and `openspec/changes/resolve-flutter-analyzer-diagnostics-pr2.zip`. Read all four artifacts and AGENTS.md, inspected six inputs/five outputs and resolved generator sources. Snapshots and ownership hashes are retained outside source at `/tmp/moliseis-pr2-p1-before/` (ephemeral). Only proposal/design/tasks were revised; metadata, ZIP and all other preexisting tracked/untracked file hashes are preserved.

D2/G0–G5 now requires generation and independent reproduction from final sources; compatibility does not waive synchronization. Proposal, linked tasks, risks, scope and acceptance were reconciled. D1/D3/D4, diagnostic distribution/matrix and unrelated tasks are unchanged; all 20 tasks remain unchecked. Independent read-only review found no remaining material P1 contradiction. Strict OpenSpec validation passed (exit 0), specs remain skipped, both git whitespace checks passed and all untracked artifacts were separately whitespace/diff audited against remediation snapshots. These are document verification results only: no generation, implementation or Flutter tests ran during remediation; no commit/push/PR/merge/sync/archive. The gate is specified and reviewable, not claimed executed. Status: P1 REMEDIATED — READY FOR FINAL ADVERSARIAL REVIEW; external review and explicit authorization remain necessary before apply.
