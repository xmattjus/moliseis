## Why

Content Submission now has durable draft identity, explicit checkpoints, and durable staged assets, but its route lifecycle can still lose or resurrect uncheckpointed form edits, launch external destinations without first making edits durable, push duplicate progress routes, and couple successful-session cleanup to individual progress-screen navigation buttons. Subplan 3 hardens those boundaries on top of the completed Subplans 1 and 2 without replacing the existing Flutter UI, `go_router`, Provider, ViewModel, or Command architecture.

## What Changes

- Guard removal of the Content Submission form route: clean sessions exit directly, while dirty sessions offer exactly `Salva ed esci`, `Esci senza salvare`, and `Annulla` with explicit checkpoint, checkpoint-revert, and cancellation semantics; only the owning exit invocation may receive affirmative permission, so overlapping removals cannot consume the same decision and remove another route.
- Prevent a native iOS edge-swipe from starting while the form is dirty, because an asynchronous dirty-exit dialog entered after an interactive Cupertino pop has started can leave the route visually frozen. Keep the existing AppBar Back exit policy, retain clean native swipe-back, and show a secondary `● Modifiche non salvate` status line within the unchanged standard AppBar geometry.
- Add the minimum ViewModel lifecycle operation needed to restore only uncheckpointed form fields to the last checkpoint while preserving the persisted draft, session identity, and already-durable staged-asset state.
- Checkpoint dirty form data before opening Terms or Privacy destinations, and checkpoint the validated current draft before starting submission or pushing the progress route; reuse the existing generic error feedback when a boundary cannot be crossed safely.
- Serialize each form-owned external/submission transition at the UI/navigation boundary and mutually exclude it from parent-form removal, so rapid repeated interaction, system/predictive Back, AppBar Back, or programmatic removal cannot overtake a pending checkpoint, start competing persistence, or trigger a late launch/submit/progress transition.
- Move successful local session finalization into the ViewModel-owned submission lifecycle, remove cleanup policy from progress-screen navigation buttons, preserve failed/idle work, and distinguish a confirmed remote success whose local finalization must be retried without resending the submission.
- Preserve the dedicated progress route and its running-state `PopScope`, while defining deterministic Back, `Torna al modulo`, `Riprova`, `Torna alla home`, and `Nuovo suggerimento` behavior across running, restored-idle, remote-failure, finalization-failure, and success states.
- Add focused ViewModel, form, route, progress, restoration, system-back, and predictive-back regressions, including controllable-gate tests for overlapping removals and form-boundary-versus-exit races; retain manual iOS gesture validation only where Flutter's widget harness cannot reliably prove the native interactive gesture.
- Make no Supabase, Edge Function, RPC, RLS, migration, Cloudinary, package, generated-code, Admin, or unrelated business-validation changes, and do not describe this subplan as whole-program release readiness.

## Capabilities

### New Capabilities

- `content-submission-navigation-lifecycle`: Defines guarded form exits, external and submission checkpoints, duplicate-transition prevention, progress-route ownership, failure preservation, and exactly-once successful local session retirement.

### Modified Capabilities

None. The active predecessor deltas `content-submission-draft-persistence` and `content-submission-local-asset-staging` remain unchanged and are reused as implemented baselines.

## Impact

- Production scope is expected to remain within `lib/routing/router.dart`, `lib/ui/content_submission/view_models/content_submission_view_model.dart`, `lib/ui/content_submission/widgets/content_submission_screen.dart`, and `lib/ui/content_submission/widgets/content_submission_progress_screen.dart`.
- Focused tests will update the existing Content Submission ViewModel/form/progress/restoration suites and add or extend a production-shaped route guard test; shared fakes/helpers may receive only narrowly required counters, gates, or fixture wiring.
- `lib/utils/command.dart`, domain/data repository contracts, ObjectBox schemas/generated output, dependency files, and backend code are not expected to change.
