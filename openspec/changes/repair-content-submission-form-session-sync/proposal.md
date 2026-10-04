## Why

The mounted public Content Submission screen synchronizes identity changes with `FormState.reset()`, which invokes text-input callbacks and can make the ViewModel's freshly retired clean session dirty. This explains the erroneous post-success Home confirmation; late persisted-session adoption is a separate candidate for the reported empty-form confirmation and must be tested before attributing that symptom to the same cause.

## What Changes

- Replace identity-driven imperative form reset with replacement of both session-owned Form states, presenting the authoritative ViewModel snapshot without synthetic edits or persistence.
- Preserve structural dirty comparison, valid clean recovery, successful identity-bound retirement, staged-asset ownership, all-day behavior, and existing navigation policy.
- Require pre-fix regression evidence for post-submit mutation and stale recovered contact values. Test gated late adoption without forcing a failure; record a passing baseline as evidence against closing Bug B through this repair.
- Correct existing UI assertions that accept empty strings in the domain fresh draft while retaining empty visual text assertions.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-submission-navigation-lifecycle`: require session presentation replacement to preserve authoritative snapshots without invoking user-edit callbacks or introducing dirty exits.

Consume `content-submission-draft-persistence` and `content-submission-submit-orchestration` as existing invariants; no delta is needed for either.

## Impact

Expected production change: only `lib/ui/content_submission/widgets/content_submission_screen.dart`. Tests: existing screen and production-router suites; reuse shared fakes and existing rich-text/all-day/VM/progress/restoration suites. No dependency, ViewModel, domain, router, progress, repository, ObjectBox, backend, or Admin production changes.

Planning baseline: HEAD `1190334e3b63dce5637a732ee3dcced2c93a01a8`, with preexisting local changes documented in design.md. This change contains planning only; deterministic new regression execution belongs to the first implementation gate.
