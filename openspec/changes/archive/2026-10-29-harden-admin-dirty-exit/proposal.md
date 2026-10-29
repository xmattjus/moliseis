# Proposal

## Why

Admin New and Edit retain durable sessions but lack a unified field dirty-exit decision. Using moderation dirtiness for this purpose would prompt for already checkpointed remote work and durable assets, while restoring the physical checkpoint could undo a newer accepted effective baseline.

## What Changes

- Introduce a shared presentation-only `lib/ui/core/ui/unsaved_changes_dialog.dart` with typed `saveAndExit`, `discardAndExit`, and `cancel` decisions, responsive Material 3 Expressive presentation and accessible keyboard behavior.
- Add one Admin route-exit policy, using uncheckpointed fields rather than `isDirty`, with single-flight transition ownership, exact activation/route authority and immediate auth revocation.
- Save and Exit explicitly checkpoints locally; it never invokes remote Create/Update, upload, association or moderation. Preserve explicit Save/Progress admission and running-operation barriers.
- Add activation-checked field discard to the effective baseline without changing physical persistence, remote evidence, staged work, unresolved intents or recovery obligations.
- Preserve Public Content Submission exit semantics, replacing only its inline dialog with the shared presentation.
- Preserve same-session restoration, pending recovery checkpoint protection, successful moderation closure and normal progress return.

## Capabilities

### New Capabilities

- `unsaved-changes-dialog`: Presentation-only typed decisions, responsive theme integration, semantics and desktop input.

### Modified Capabilities

- `admin-submission-editor`: Unified guarded exit and target-transition behavior for New and Edit, distinct from remote Save and moderation dirtiness.
- `admin-draft-persistence`: Activation-checked restoration of effective fields without persistence or loss of recovery evidence.

Public adoption changes no Public requirement; its existing navigation and draft specifications remain acceptance constraints.

## Impact

Implementation seams are the existing router, Admin route binding/editor screen/ViewModel and `AdminDraftSession`, plus one core UI dialog and focused tests extending shared harnesses. No new package, generic navigation framework, session manager, DI system, backend contract, migration, generated model or draft-storage schema is required. Canonical specifications were unchanged during planning and implementation; the completed deltas are synchronized in the separately authorized archival documentation workflow.

Archived Admin Plans 1–3 are authoritative prerequisites. `improve-admin-submission-editor-workflow` remains historical and must not be applied, synchronized, archived as delivered or edited by this change.
