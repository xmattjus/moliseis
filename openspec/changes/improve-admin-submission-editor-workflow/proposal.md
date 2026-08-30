## Why

The admin submission editor currently closes after a successful Save and hides image selection until a new submission has first been persisted, forcing administrators through unnecessary reopen cycles. Both problems require the same editor session to transition safely from an in-memory draft to a persisted pending submission while preserving retryable local work.

## What Changes

- Keep the admin submission editor open after a successful create or update Save instead of popping the route.
- After a successful create response is received and its persisted identity is adopted by the live editor, make that same session represent the returned pending submission without route replacement or a redundant detail reload; later Saves in that session reuse the adopted identity and do not invoke create again.
- Make Publish and Reject immediately available after a successful Save whenever the existing moderation and publication-readiness guards allow them.
- Allow administrators to select and remove local images before the first Save. These images remain staged in memory and are not uploaded while the live editor has no adopted persisted identifier.
- After the first create response has been adopted, persist staged images sequentially in selection order through the existing image-upload and admin asset-association paths, without introducing a new backend contract.
- Preserve monotonic progress if asset persistence fails after create adoption: keep the adopted submission identifier and confirmed assets, retain failed and unstarted images plus any successful upload result needed for retry, keep moderation unavailable, and do not return that live editor session to the create path.
- Preserve the existing immediate upload behavior when adding images to a submission that was already persisted before the current image selection.
- Document the existing distributed ambiguity limits honestly: a create that commits but whose successful response is not received/adopted may be repeated and create a duplicate submission, and an asset association that commits but whose response is lost may be repeated and create a duplicate association. Exactly-once recovery for either case is outside this frontend-only change.
- Refresh the admin submissions dashboard after the editor route exits regardless of whether the route was originally opened for create or edit, so Save no longer needs to pop with a `true` result merely to trigger a refresh.
- Add focused ViewModel and widget regressions for the continuous-save flow, transient-to-persisted transition, staged-image capacity/removal, persistence ordering, failure recovery, moderation readiness, and dashboard refresh behavior.

## Capabilities

### New Capabilities

- `admin-submission-editor`: Defines the lifecycle and asset-staging behavior of the route-scoped admin submission editor, including its transition from a new in-memory draft to a persisted pending submission.

### Modified Capabilities

- None.

## Impact

- Flutter state management: `AdminSubmissionEditorViewModel` must represent a persisted identifier acquired from a successful create response while live, adopt that result, distinguish unsaved fields from staged persistence work, retain successful upload metadata across association failure, and orchestrate sequential staged-image persistence.
- Flutter UI: `AdminSubmissionEditorScreen` must stop popping after Save, expose the photo section in create mode, render/remove staged images, and simplify status-dialog handling that exists only to coordinate the old Save-pop behavior.
- Admin dashboard/navigation: reload the submissions list after the editor route returns rather than depending on Save to return `true` immediately.
- Tests: extend the existing shared admin repository/image-picker support, admin editor ViewModel/widget tests, and dashboard navigation coverage for success, failure, retry, disposal, mode-transition, and refresh behavior.
- Backend: no database migration, idempotency key, reconciliation protocol, RPC signature/body change, Edge Function endpoint change, repository protocol addition, storage-policy change, or Cloudinary signing change is intended. Existing `create`, image-upload, and `addAsset` paths are reused with their current ambiguous-response limitations.
- Compatibility: persisted pending submissions retain their current immediate image-add behavior; accepted/rejected submissions remain read-only; the five-image invariant remains authoritative in the existing RPC.
