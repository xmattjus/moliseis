# PR #12 OpenSpec finalization closeout

**LOCAL ARCHIVAL COMPLETE — ACCEPTED WITH DOCUMENTED STRICT-VALIDATION EXCEPTIONS**. Final independent review completed with no material finding remaining. No publication is authorized.

Repository: `xmattjus/moliseis`. Execution date: 2026-10-25, Europe/Rome.

## Baseline and isolation

PR HEAD: `33377ea6ac0cd8b75562fc9d82c6da885705224a`. PR base: `main` at `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. The connected GitHub metadata was rechecked: PR #12 remains open and Draft, source `codex/migrate-legacy-commands`, with the expected HEAD and base. Dedicated branch `codex/plan-pr12-openspec-finalization` and existing sibling worktree `moliseis-worktrees/pr12-openspec-finalization` were reused without a new checkout, branch move or rebase.

Initial state: canonical specs and eight active target directories matched the blocked baseline; no target archive existed; the real index was empty; exactly the two existing closeout artifacts were untracked. All 68 source artifact files matched their recorded SHA-256 manifests. The installed OpenSpec version remains **1.14.3**; merge, parser and archive implementation hashes match the previous execution. Archive destination naming and collision checks were inspected in the installed implementation.

The eleven other worktrees retain identical HEAD/branch/status, exact Git index bytes and tracked/nonignored untracked file hashes before and after execution. Ignored build products are outside that recorded inventory. No other checkout was written.

## Provenance: initial blocked attempt

`pr12-finalization-evidence.json` is the original blocked-closeout record, preserved **byte-identically**. Its SHA-256 is `b41f0e0e633af1858aaf266c109b0a14dddeeb551217a292f9b7b869371990a5`. It records successful isolated composition and eight CLI archives, followed by failed global strict canonical validation and the independent reviewer’s confirmation that stopping was justified under the original authorization. Its historical `persistent: []` and blocked disposition describe that earlier attempt; they are not the current persistent state.

The original human-readable blocked report has been superseded by this report. Its historical hash is recorded in `pr12-finalization-gate-reconciliation.json`; no initial failure was rewritten into a successful historical execution. The new reconciliation record references the existing full source manifests and evidence rather than duplicating the original two-megabyte record. All archived proposals, designs, planning history, review conclusions, test manifests/transcripts, metrics, hashes and SHA/parent references remain unchanged.

## Explicit gate reconciliation

The resumed user instruction explicitly authorized exactly two task-scoped exceptions. Normative requirements, delta contents, historical checkboxes, validator configuration and installed tooling were not changed. `--strict` remains in every global validation command.

### Exception A: requirement-length warnings

The actual diagnostic schema was inspected: top-level `items`, `summary`, `version`, `root`; each item has `id`, `type`, `valid`, `issues`, `durationMs`; issues have `level`, `path`, `message`. The original enriched record also has `requirement`. Every issue shape was checked; unsupported fields or unrecognized paths fail closed. Requirement indexes were resolved through the installed OpenSpec parser, and the resulting stable identities were checked against the recorded requirement annotations. Raw and enriched original reports agree.

Diagnostics were compared as **multisets**, keyed by capability, requirement identity, severity and exact message. The original 92-warning multiset is fully retained. The final 95-warning multiset differs by exactly:

- `command-execution-concurrency` / `Only authoritative completion can commit asynchronous data`
- `command-execution-concurrency` / `Admin editor revocation preserves private physical settlement`
- `content-submission-submit-orchestration` / `Immediate retry availability is derived from authoritative submission state`

All 95 findings are WARNING-level requirement-length diagnostics with the same exact message:

> Requirement text is very long (>500 characters). Move examples and edge cases into scenarios, or split it into separate requirements that each state one behavior.

No baseline warning disappeared; no unexpected requirement, new diagnostic severity/category or unrelated validation error appeared. Baseline and fixture validation were rerun before persistent writes. Final persistent validation matches the previously accepted final signature exactly. The reconciliation JSON contains full stable signatures and their SHA-256 values.

### Exception B: one historical incomplete archive

`openspec/changes/archive/2026-10-07-harden-main-navigation-shell/tasks.md` remains byte-identical at SHA-256 `86547d14a56f7a8f6fa77210bdbd0c96579ea04d9587d589083cd8d6b2ef4972`. Its actual completion remains **40/42**. Global archived validation has exactly one failure: `2 incomplete tasks (40/42 completed)`. All other 31 archives, including all eight PR #12 archives, pass task completion validation. No checkbox was changed and no historical archive was rewritten.

| Validation command | Actual exit | Actual result | Acceptance |
|---|---:|---|---|
| `openspec validate --specs --strict --no-interactive --json` — baseline | 1 | 92 length warnings, 14 affected specs | Recorded baseline |
| Same command — existing fixture and final persistent tree | 1 | Exactly 95 length warnings, 14 affected specs | Exception A |
| `openspec validate --archived --strict --no-interactive --json` — fixture and final persistent tree | 1 | 31/32 valid; the one historical archive remains 40/42 | Exception B |

**ACCEPTED WITH DOCUMENTED STRICT-VALIDATION EXCEPTIONS**. These CLI commands failed as reported. Global strict validation remains red; it is not represented as successful.

## Pre-archive verification and evidence reuse

Initial canonical counts were **17 capabilities / 169 requirements / 635 scenarios**; inventory was **11 active / 24 archived** changes. All eight source task sets remained complete. The previous real-archive fixture was retained and checked: every archived artifact hash, archive operation exit code and final canonical file hash still matches the source record. Its JSON `archive` envelope was explicitly inspected for specification updates and warnings; all eight operations updated specs and returned no warnings.

A fresh disposable composition replay applied the unchanged deltas in the mandatory sequence using installed `findSpecUpdates` and `buildUpdatedSpec`; every checkpoint matched the previously recorded canonical hashes. No competing merger/parser was implemented. This reproduced output is byte-identical to both the original composition and real-archive fixture. No unnecessary new eight-archive simulation was run. Archive/spec instructions and current artifact/task statuses were checked before persistent execution.

## Persistent archive operations

Every row executed `openspec archive <change-name> --yes --json`, with neither skip flag. `TZ=Europe/Rome` was used. The installed local-calendar date resolver and destination absence were checked immediately before each operation. Every operation returned exit 0; source directory absence, unique archive destination, all moved artifact hashes, progressive canonical hashes, remaining source directories, unrelated active changes and all 24 existing archives were verified before continuing.

| # | Change | Actual archive destination | Exit | Artifacts | Completed tasks |
|---|---|---|---:|---:|---:|
| 1 | `migrate-simple-view-model-commands` | `openspec/changes/archive/2026-10-25-migrate-simple-view-model-commands` | 0 | 5 | 27/27 |
| 2 | `migrate-category-view-model-commands` | `openspec/changes/archive/2026-10-25-migrate-category-view-model-commands` | 0 | 5 | 21/21 |
| 3 | `migrate-content-view-model-commands` | `openspec/changes/archive/2026-10-25-migrate-content-view-model-commands` | 0 | 6 | 27/27 |
| 4 | `migrate-search-map-commands` | `openspec/changes/archive/2026-10-25-migrate-search-map-commands` | 0 | 6 | 27/27 |
| 5 | `migrate-content-submission-commands` | `openspec/changes/archive/2026-10-25-migrate-content-submission-commands` | 0 | 8 | 32/32 |
| 6 | `migrate-admin-session-commands` | `openspec/changes/archive/2026-10-25-migrate-admin-session-commands` | 0 | 7 | 24/24 |
| 7 | `migrate-admin-editor-commands` | `openspec/changes/archive/2026-10-25-migrate-admin-editor-commands` | 0 | 13 | 27/27 |
| 8 | `simplify-migrated-view-model-commands` | `openspec/changes/archive/2026-10-25-simplify-migrated-view-model-commands` | 0 | 18 | 9/9 |

The complete source file manifests and directory content hashes remain in the unchanged original evidence. The reconciliation record references them per operation and records each resulting canonical hash tree. All **68 original files** were relocated without byte changes. No duplicate active/archive copy remains.

### Audit consumer interruption

After the first successful archive, the audit harness asserted `archivedAs` at the JSON envelope root rather than inside `archive`. The CLI had already exited 0. Execution paused; the installed envelope and prior outputs were inspected, and the harness reader was corrected. The completed first operation’s canonical checkpoint, unique destination, full source artifact hashes and remaining active sources were then verified before proceeding to operation two. No archive was rerun or rolled back, no canonical text was edited, and no failed CLI execution was concealed. The original assertion and its verified resolution are retained in `auditInterruption` in the reconciliation record.

## Final canonical integrity

Final inventory: **17 capabilities / 240 requirements / 975 scenarios**. `command-execution-concurrency`: **59 requirements / 290 scenarios**. Persistent canonical file hashes match the reproduced composition and original archive fixture **byte-for-byte**, at every checkpoint and for the full final tree.

Installed operation order remains RENAMED → REMOVED → MODIFIED → ADDED. The eighth delta contains **7 renames, 13 modifications, 0 additions and 0 removals**, and introduces **3 scenarios**. Each obsolete rename identity is absent and each replacement occurs once. All thirteen modified requirement bodies match the approved delta exactly. The unchanged composition checks preserve historical scenario identities, scope and membership; approved modifications intentionally supersede their earlier wording. Untargeted requirements and unrelated capabilities retain their normative content. There are zero duplicate or orphan requirements and zero duplicate scoped scenarios.

The only previously documented raw-format normalization is removal of an extra blank line in `Durable submission attempt` before `Earlier staging commits before membership capture`, performed by the official engine. No new formatting difference appeared. The thirteen eighth-delta bodies require no normalization for their exact comparison.

### Seven rename results

| Previous identity | Final identity |
|---|---|
| Search history deduplication respects repository identity and knowledge | Search history mutations use repository identity rules |
| Search history rollback rebases later accepted intentions | Search history presentation retains confirmed data |
| History read authority changes at mutation acceptance | History reads remain independent of accepted writes |
| Runtime write failure requests bounded history reconciliation | Runtime history write failures allow explicit read-only recovery |
| History read demands distinguish stale errors from retry loops | History read failures terminate without automatic retry |
| Explicit history refresh registers independent read demand | Explicit history refresh uses ordinary single-flight admission |
| Editor changes retain an owner-local refresh obligation | Editor return requests best-effort dashboard refresh |

The thirteen final modified identities and the three added scenario names are preserved in `pr12-finalization-evidence.json` under `priorVerifier`; the now-archived authoritative delta is `openspec/changes/archive/2026-10-25-simplify-migrated-view-model-commands/specs/command-execution-concurrency/spec.md`. The prior unsynchronized rename-source INFO does not occur against the progressive baseline or final canonical tree.

### Final canonical hash ledger

The tree digest uses SHA-256 of the UTF-8 compact JSON-encoded, lexically sorted `[relative path, file SHA-256]` pairs. Final canonical tree SHA-256: `d4867b8f1d891a40470f4f421457506f45fb8bf17b6c05502ea1104f09f37c3d`.

| Canonical path | SHA-256 |
|---|---|
| `openspec/specs/app-typography/spec.md` | `5b5b36706e8e7765114cd2c34b3f4b7211591955c2f8a5427e216a23a6b58b6c` |
| `openspec/specs/canonical-app-routing/spec.md` | `8687cd24b66130df5865a81e4c44b7473a1ac8f1f8d433e2ca41fa2d7d65d06e` |
| `openspec/specs/command-execution-concurrency/spec.md` | `c33159822de065afead0aa1de04e7282baaf8d18e34ada8c92ad1a61f15d7eac` |
| `openspec/specs/content-submission-draft-persistence/spec.md` | `55f04c5ab139cb46246b5ee051b7d1ec150e346150017c185c400d69125e6344` |
| `openspec/specs/content-submission-edge-boundary-validation/spec.md` | `f880400474f2ddf9bc8c747be08192a0867399aeb0971b34594acc707e1df813` |
| `openspec/specs/content-submission-local-asset-staging/spec.md` | `6457a4c532c613bbae62e6315c25250bd3648e0bfa57a23d8d7c41bce15de78c` |
| `openspec/specs/content-submission-navigation-lifecycle/spec.md` | `feea11c7f3af3c8333533d2f257cd49696b02d37c3b838e8ae6dc2ac474032b2` |
| `openspec/specs/content-submission-server-idempotency/spec.md` | `cb5ddb0088a9f9428b3f2a16f3f78f1b983f425d434bee36877b0914cb08919d` |
| `openspec/specs/content-submission-submit-orchestration/spec.md` | `2d4a561d4faa0f8715c90e80cccc933404475dc9b3276f2f58a3db3858040663` |
| `openspec/specs/event-all-day-semantics/spec.md` | `8908dbed0bd258f2a1f210ebe1cbe8f7d56df2609c4085f864cc369167eee7e4` |
| `openspec/specs/event-temporal-input-validity/spec.md` | `147b89eea3feb7e351063f7ec33867b5f71153ef70d62e22446969086e14121f` |
| `openspec/specs/event-temporal-integrity/spec.md` | `2f905bfd625fa426e432784f907db48f1a80f7e064cbca10c4f4d81070ce2197` |
| `openspec/specs/external-event-provenance-moderation/spec.md` | `45f79350245c8ecb882c1e91f7ef35a53cc3f8e03c371d467e1c3b4f7addff50` |
| `openspec/specs/home-ongoing-events/spec.md` | `c86e9705512ef88eac7ada56c29d14252e172410bd7c5541416fd7c6c368bee4` |
| `openspec/specs/local-content-retrieval/spec.md` | `312837c18aed7ab304d0ba2cc31d91029f848045089b9b1415649299d6479987` |
| `openspec/specs/main-navigation-shell/spec.md` | `6455f7c70347fa7174c93bf029caa41c6b53764f210228f28bf40ad3b50a06c5` |
| `openspec/specs/submission-promotion/spec.md` | `786d77815e506961044dcfe78d629dc23a458baa2a11636b1efd2f03fc180a01` |

## Final inventories and complete diff

There are **3 active / 32 archived** changes, with exactly eight new archives. No target change remains active. The three preserved active changes are:

- `harden-geo-map-semantic-state`
- `improve-admin-submission-editor-workflow`
- `optimize-content-sync-delta-retrieval`

The reconciliation JSON contains the complete final archive directory inventory and exact modified/deleted/added path inventory. Git represents the local changes without staging as 7 modified canonical files, 68 deleted active artifacts, and 71 untracked added files: 68 archive artifacts plus the three closeout artifacts. Directory relocations preserve every original byte; ordinary unstaged diff alone omits the untracked additions.

A complete patch is prepared outside the repository and replayed against a fresh export of PR HEAD. Independent review found that the initial external patch included two unrelated ignored `.DS_Store` files; the patch builder was corrected to use only the intended Git path inventory. Neither ignored file was removed or edited. The reconstruction compares the intended OpenSpec file/hash tree selected from tracked and nonignored untracked files, including all new archive and closeout paths. Existing ignored Finder metadata is excluded and left untouched. Patch location and final hash are supplied with the review handoff, avoiding a self-referential patch hash inside its own content. The real Git index is never used for patch generation or replay.

## Final independent review

The configured independent reviewer inspected the actual persistent worktree, baseline-relative diff, canonical specs, all eight archive directories, full artifact manifests, both fixtures and exact two-exception reconciliation. **No material finding remains after remediation.** The reviewer independently reran strict canonical validation (exit 1; exactly the accepted 92+3 warning multiset) and archived validation (exit 1; solely the unchanged 40/42 historical archive). All eight target archives pass. The reviewer confirmed 68 Git-baseline artifact hashes, seven renames, thirteen exact eighth-delta bodies, three new scenarios, historical scenario and untargeted-content preservation, final 17/240/975 inventory with concurrency 59/290, byte equivalence to both fixtures, unchanged original blocked evidence and preservation of the three unrelated active changes, 24 historical archives and eleven other worktrees.

The sole material handoff finding, **IR-PATCH-1**, is resolved: ignored Finder metadata was excluded from the external patch without changing or deleting either local ignored file. The reviewer independently verified that the corrected replay reconstructs exactly **244 intended OpenSpec files**. This completed review disposition was then added to the report and reconciliation record; the final patch was regenerated and replayed again to include those closeout-only updates. No normative, archival or historical evidence correction was required.

## Restrictions and remaining limitations

All changes remain local and uncommitted. Real Git index is empty. No application, test, dependency, backend, AGENTS, OpenSpec configuration, unrelated active change or historical archive was modified. No commit, push, PR update, merge, rebase, reset, clean or stash occurred. Historical application/CI results were preserved with their original attribution; application tests were not rerun for this documentation-only operation.

**The OpenSpec finalization passed its task-specific, baseline-aware acceptance gate with two documented exceptions. Global strict validation remains red and was not represented as successful.**
