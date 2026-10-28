# Proposal

## Why

Admin Save discards the returned remote identity, closes the editor, and cannot safely retry an ambiguous Create or staged association. Plan 1 supplied tested local foundations but deliberately did not integrate them; this change activates them as one coherent editing and Save lifecycle.

## What Changes

- Own one active Admin editor in the application Provider lifecycle, with account isolation, captured activation authority, explicit local checkpoints and protected remote hydration.
- **BREAKING (Admin wire contract):** Require UUID Create and exact-token Update; older Admin clients omitting them fail closed until upgraded. Public behavior and backend contracts remain unchanged.
- Reuse the local session UUID as a server-enforced Create replay key. Adopt the returned remote identity atomically in local storage without replacing the session or its files; subsequent Saves use Update.
- Permit private local image selection before Create, persist upload receipts, and process staged images in deterministic order with resumable confirmed progress.
- Fence Admin Update with the existing exact database field-version token so a request outstanding across process death cannot overwrite a later Save.
- Add an Admin-only association replay RPC using an exact uploaded receipt under the existing parent lock, without global URL uniqueness or new asset identity fields.
- Admit Save before opening an observing progress route. Keep the editor open, preserve complete terminal failure behavior, and refresh the dashboard independently of a true pop result.
- Preserve Public Content Submission production code, successful Android lost-media recovery, canonical contracts and regression expectations unchanged. Scope Android hardening to Admin editor restoration and captured live-request authority; accept the pre-existing shared native cache attribution limitation as a residual risk.
- Keep Admin ImagePicker.pickImage(source: ImageSource.gallery) with the pinned dependency. Preserve normal callbacks after resume; release stranded Admin admission only on actual authority revocation or Admin-only Interrompi selezione, without claiming native cancellation.
- Supersede the strict native correlation/inbox handoff from archived Plan 1 with Admin-only best-effort media handling and independent same-account editor restoration, without rewriting history or changing Public.

## Capabilities

### New Capabilities

- `admin-submission-editor`: application-owned activation, Save/identity/staged progress and editor/dashboard behavior.
- `admin-submission-save-idempotency`: authenticated Admin Create replay and exact-receipt association replay.
- `editor-picker-restoration`: Admin-only editor restoration and picker lifecycle, with Public preservation as a scope constraint.

### Modified Capabilities

- `admin-draft-persistence`: activate the production consumer and permit atomic confirmed identity adoption while retaining owners.
- `admin-local-asset-staging`: retain private staging isolation while adding separate durable remote-progress receipts.

## Impact

Flutter domain/local repositories, ObjectBox generator inputs and mappings, Admin ViewModel/screens, Provider composition, auth integration, Admin router constants/restoration. Public production code, picker/recovery integration, initialization, lifecycle and tests are not modification targets. Backend changes affect Admin validation/dispatch/store, a small Create RPC, conditional pending Update and singleton association RPC, service-role-only grants, shared database types and focused Edge/real-PostgreSQL tests. Existing schema uniqueness and pending/five-image boundaries are reused. No new package or native dependency is proposed.

Plan 1 is complete at baseline `9598e80c05f4483d7fabbda064cdaf71ac503609` (the exact audited hash is recorded in design). Backend contracts must pass before client activation. At planning time deployment state was unverified; repository migrations were not deployment evidence. Subsequent implementation, Android acceptance and separately authorized production deployment/read-only parity verification are recorded in tasks.md, including the Admin-only compatibility window and rollback decision.

## Non-goals and dependency decisions

No implementation occurs during planning. No full conflict-resolution UX (Plan 3), dirty-exit dialog (Plan 4), moderation progress-route migration, generic workflow/session/staging framework, Cloudinary protocol change, native fork, shared picker/recovery gateway, cache-isolation protocol, durable recovery inbox or owner retirement. The historical `improve-admin-submission-editor-workflow` remains unimplemented and is not an executable alternative. Canonical specs and archived history remain unchanged until implementation acceptance.
