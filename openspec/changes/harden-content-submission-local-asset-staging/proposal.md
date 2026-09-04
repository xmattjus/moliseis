## Why

Content Submission drafts now retain a stable local identity and can be checkpointed explicitly, but selected attachments still reference picker-owned `XFile` paths that may disappear across ViewModel recreation or Android process death. Local asset ownership therefore needs to become as durable as the draft session, and this is the first production flow that requires both an awaited pre-picker `checkpointDraft()` call and cross-Command lifecycle arbitration.

## What Changes

- Require the current draft identity to be known durable before opening `ImagePicker.pickMultipleMedia()`, while tracking durable existence separately from checkpoint-snapshot equality so a fresh empty draft is physically persisted once.
- Use `ContentSubmissionDraft.clientSubmissionId` as the only ownership, query, deduplication, restoration, removal, cleanup, and stale-session key.
- Add one Content Submission-specific local staged-asset boundary backed by ObjectBox descriptors and private Application Support files; descriptors contain only `clientSubmissionId`, the existing SHA-1 content digest, and a path relative to the feature staging root.
- Funnel normal picker results and Android lost-data files through one `validate → digest → dedupe → stage → persist descriptor → runtime Asset` pipeline, with runtime `Asset.file.path` reconstructed from the staged copy.
- Add one small private lifecycle serialization boundary across local staging commits, recovered-data processing, removal, staged cleanup, and clear/session rotation; keep external picker interaction outside it and reject results captured for a stale draft identity without a generic user-facing error.
- Coordinate draft loading, staged filesystem/ObjectBox reconciliation, explicit descriptor ordering, asset restoration, and the `loadState == ready` transition.
- Reject submission before any upload or final remote operation while staged restoration is unavailable or quarantined, so an untrusted durable attachment set can never be silently submitted as empty.
- Preserve early Android `retrieveLostData()` acquisition while delaying recovered-file processing until initialization and staged-state reconciliation complete.
- Treat ViewModel disposal as terminal for post-picker and post-removal runtime publication while preserving any already committed staged state for the next initialization.
- Persist single-asset removal, provide idempotent per-session cleanup, and remove temporary, stale-descriptor, missing-descriptor, and non-active orphan state through deterministic reconciliation.
- Preserve staged source files across Cloudinary or remote submission failure and prove initial upload and retry read the staged file rather than the original picker path.
- Retain the existing Commands, maximum-five and file-size UX, sequential Cloudinary uploads, remote retry/error behavior, and no-rollback semantics.

## Capabilities

### New Capabilities

- `content-submission-local-asset-staging`: Durable, single-session local attachment ownership, staging, restoration, Android recovery, reconciliation, removal, cleanup, and retry-source guarantees before remote submission.

### Modified Capabilities

None.

## Non-Goals

- No Content Submission UI, navigation, progress-route, upload, cancellation, or remote retry redesign.
- No Cloudinary deletion/rollback, parallel upload, background work, compression/transcoding, MIME enrichment, or remote/local distributed transaction machinery.
- No Admin staging implementation, shared public/Admin media framework, multi-draft UX, generic media manager, global mutex, Command scheduler, or generic `Command` redesign.
- No Supabase schema, `content_submissions`/`submissions_assets`, RPC, RLS, Edge Function, Cloudinary-signing, or promotion change.
- No claim that Content Submission is release-ready before the remaining hardening subplans are implemented and verified.

## Impact

- Affects the Flutter Content Submission ViewModel lifecycle and its existing screen/asset-list behavior only where required to stage, restore, remove, and render durable local files.
- Adds a minimal local staged-asset domain/data model, ObjectBox entity and generated metadata, Content Submission-specific repository implementation, private filesystem storage, Provider registration, and replaceable test boundary.
- Uses the already-declared `crypto`, `image_picker`, `objectbox`, `path`, and `path_provider` dependencies; no new package is expected.
- Extends existing Content Submission, real-ObjectBox, filesystem, lifecycle/concurrency, Android recovery, restoration, removal/cleanup, and remote retry tests.
- Leaves public remote models such as `SubmissionAsset`, the `submit-content` path, `submissions_assets`, `add_submission_assets`, `delete_submission_asset`, and the independent backend maximum-five invariant unchanged.
