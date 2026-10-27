# Definition validation and review handoff

## Scope and baseline

This is an OpenSpec definition, not implementation. Audited baseline after successful `git fetch origin`: `355bc678836894c72cbec31d5929076a1fe8cc79` (`origin/main`). Plan branch: `codex/plan-harden-admin-draft-and-staged-assets`, dedicated managed worktree. The primary checkout was initially clean on `docs/archive-geo-map-semantic-state` at `245e3b80c2d32c7434d6099dc6041643d3a74a63`; that branch/commit remains preserved. Primary checkout is now clean on `main` at the fetched baseline. No user working-tree content was discarded.

Only the new change's artifacts and a two-line supersession notice in the obsolete Admin proposal are authored. Old requirements/tasks remain unimplemented and unchanged; canonical specs are not synchronized. The proposed OpenSpec deltas express future behavior and are not evidence that it exists.

## Evidence and decisions

See `design.md` for source/version inventory, complete Public precedent disposition, backend boundaries and the old Admin requirement-by-requirement mapping. Read-only exploration was split between Public and Admin/backend; the main author inspected material sources and reconciled conclusions. A separate focused architect/reviewer audit challenged the definition. This authoring review is not the requested subsequent independent approval.

Corrections incorporated during authoring:

- Inbox acknowledgement failure followed by explicit removal cannot resurrect an image. Removal waits for startup acquisition outside feature arbitration, durably rejects matching inbox references, then removes the feature descriptor.
- Startup empty/error with a surviving Android ticket does not prove physical picker settlement. Replacement launch is blocked; no second retrieval, timed expiry or guessed reassignment.
- A non-durable Create cannot acquire an unfenced checkpoint midway through its remote await. Create reserves durability and fields; an earlier checkpoint settles before durability/fence determination.
- A fenced uncertain new session can be explicitly parked without deletion before a separate new draft starts. No remote result resolution or ID adoption is implied.
- Fresh remote associated-count growth can exceed combined capacity. Keep all committed staged bytes, block unsafe actions, permit exact-owner local removal.
- Non-Android previous-process tickets invalidate without Android lost-cache blocking or platform retrieval.

The three spec deltas contain 27 requirements and 127 scenarios. `tasks.md` contains 46 unchecked future tasks, zero completed implementation tasks. Two Public recovery requirements are modified as complete blocks; all their previous scenario headings remain represented. All other canonical Public requirements remain outside the delta.

## Commands actually executed

- Git status/branch/remotes/worktree/log/ref inspection; successful escalated `git fetch origin`; dedicated managed worktree creation and new plan branch. Local main was synchronized to the fetched integration commit; primary later switched cleanly to main. No direct push to main.
- `openspec --version`: 1.14.3; `openspec list --json`, `context --json`, capability inventory/show, `new change`, `status`, and each artifact's schema instructions.
- `openspec validate harden-admin-draft-and-staged-assets --strict --no-interactive`: **PASS**, exit 0, repeated after review corrections.
- `openspec status --change harden-admin-draft-and-staged-assets`: **4/4 planning artifacts complete**. This status measures artifact existence, not implementation completion.
- `openspec validate improve-admin-submission-editor-workflow --strict --no-interactive`: **exit 1**, existing >500-character requirement warning in `Initial create transitions the same editor session to persisted state`. That spec file is unchanged from baseline; the new supersession notice does not create the warning. Historical text was preserved rather than opportunistically rewritten.
- Planning-file checks for trailing whitespace, final newline, symlinks and machine-specific paths: **PASS**. `git diff --check` and `git diff --cached --check`: **PASS**. Full authored artifact diff reviewed; exact nine-file planning allowlist verified, with no source/backend/canonical-spec/generated/dependency changes staged.
- Read installed pinned picker Dart/Android source; verified official 1.2.3 documentation using documentation lookup and web access. The Supabase changelog markdown fetch was unavailable; no remote/backend implementation relied on it. Checked-in SQL/Edge code supplies the audited backend contract.
- `gh --version`: 2.102.0. `gh auth status` reported an invalid CLI token; use the connected GitHub tool for PR creation if publication succeeds. No credential values were read or printed.

No Flutter tests, analyzer, build_runner, database command, deployment or device smoke was executed. All such checks in tasks are prospective; none is claimed as passing here. Temporary command output is not retained as repository evidence.

## Material accepted limitations for the independent reviewer

The Android plugin cannot prove completion from an empty startup response and consumes cached data before a durable application handoff. Consequently (1) uncommitted retrieved bytes can be lost, and (2) lost cancellation or interruption between ticket commit and launch can leave **both features' picker launches blocked indefinitely** until an attributable terminal result exists. This safety/availability decision is explicit, not a guarantee of transparent recovery. A safe abandonment/reset control requires a separately reviewed native/plugin settlement contract. This foundation is not independently release-ready.

Admin Create/association remain non-idempotent; a local UUID/fence does not make remote requests exactly-once. Remote baseline matching is not field CAS. Uncheckpointed typing and an already-returned live persisted picker selection can be lost on process death before their respective commit boundaries. These are distinct from the recovery guarantee for descriptor-backed private copies.

Plan 2 owns staged Save/remote progress/create-ID adoption/navigation; Plan 3 owns remote stale/outcome recovery; Plan 4 owns dirty exit. The old proposal is preserved pending explicit later withdrawal/supersession. Definition validity does not authorize any of that implementation.
