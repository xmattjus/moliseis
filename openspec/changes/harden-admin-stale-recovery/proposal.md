# Proposal

## Why

Admin Plans 1 and 2 already preserve local work and fence stale writes, but an incompatible fresh remote projection leaves repeated reloads unable to resolve the conflict without an explicit way to accept remote fields or authorize a new Save of preserved local fields. Complete that bounded recovery path without replacing the existing session, Save, persistence or backend mechanisms.

## What Changes

- Retain a current, immutable remote recovery observation separately from accepted remote baseline and field-write authority; show the differing editable groups and current status.
- Offer explicit whole-field choices: accept the observed remote fields, or keep local fields and authorize a later, separately admitted conditional Save against that observation.
- Require exact current activation/observation/local-revision authority and resolution of any previous field-write intent before either choice can grant mutation authority. Never lend a newly observed token to an unresolved old request.
- Distinguish retryable read/initialization failures, incompatible detail, finalized/missing targets and denied authorization, with settled local-preservation and retry/return behavior.
- Reconcile remote-change recovery with retained staged bytes and confirmed receipts; never recreate a known removed association or start remote work from a recovery choice.
- Reuse existing source/preview invalidation, account revocation, A → B → A protection and physical operation settlement, extending their deterministic tests to the new callbacks.

## Capabilities

### New Capabilities

None. Extend the existing Admin boundaries.

### Modified Capabilities

- `admin-submission-editor`: explicit field reconciliation, classified unavailable states and exact recovery-choice authority.
- `admin-draft-persistence`: explicit local-session baseline transitions without pretending that hydration or a choice wrote the physical checkpoint.
- `admin-local-asset-staging`: receipt-aware recovery after authoritative remote association changes.

## Impact

Flutter `AdminDraftSession`, the existing Admin editor ViewModel/screen and their existing domain, ViewModel, widget/route and real ObjectBox/filesystem test seams. No new package, DI architecture, local schema, RPC, Edge Function, database migration or remote API is required. Existing Admin Create replay, guarded Update, staged receipt replay and moderation guarantees remain dependencies.

Audited baseline: `69e1773f168c16d76a3d588588be7cddf97737ac`, current `origin/main` after merges #17 and #18. The baseline audit, evidence limitations and categorized gap analysis are in design.md.

## Non-goals

No Supabase/backend or Public Content Submission changes, deployment, automatic moderation, automatic merge, automatic Update retry, remote replay on initialization, owner deletion, generic conflict framework, progress-route redesign, Dirty Exit/shared Material 3 Expressive dialog (Plan 4), or reopening of the accepted Android shared-cache provenance limitation. Preserve historical `improve-admin-submission-editor-workflow` artifacts.
