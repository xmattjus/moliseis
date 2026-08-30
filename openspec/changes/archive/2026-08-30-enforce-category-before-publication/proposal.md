## Why

`public.promote_content_submission` currently copies `category = unknown` into published places and events even though `unknown` is valid only while content remains a suggestion or pending editorial submission. Publication needs a concrete category without narrowing the valid pending workflow or making a client the source of truth.

## What Changes

- Make the existing transactional promotion RPC reject `unknown` with the non-mutating domain outcome `category_required` for both place and event publication, while preserving durable-link idempotency precedence and all existing promotion behavior.
- Extend the admin Edge Function's fail-closed promotion result contract and map the new outcome to HTTP `422` with code `PROMOTION_CATEGORY_REQUIRED`.
- Keep `unknown` valid for the normal public suggestion flow and for admin pending create/update/save. Public submission without a selected category continues omitting the field so PostgreSQL applies the existing `unknown` default; public and admin production validation remain unchanged.
- Add a narrow Flutter publication-readiness guard and guidance so Publish is unavailable for an unset/unknown category, while Save and Reject retain their existing behavior and the database remains authoritative.
- Replace the database test that treats `unknown` as publishable and add regression coverage for place, event, idempotency, side effects, API contracts, allowed pending operations, and Flutter UX.

## Capabilities

### New Capabilities

- `submission-promotion`: Defines category readiness at the publication boundary and preserves `unknown` throughout the pre-publication workflow.

### Modified Capabilities

- None.

## Impact

- Database: a new migration replacing `public.promote_content_submission(bigint, text, uuid)` without changing its signature, return columns, security mode, ACL, locking, transactionality, or publication mutations.
- Supabase Edge Functions: the admin promotion store/result validation and HTTP response mapping. `submit-content` production code remains out of scope; focused test coverage may retain the existing omitted-category behavior.
- Flutter: `AdminSubmissionEditorViewModel`, `admin_submission_editor_screen.dart`, and their focused tests; the domain repository protocol does not change.
- Compatibility: existing pending `unknown` submissions remain valid and rejectable; concrete-category publication is unchanged; already-linked submissions still return their original promotion result even if their source category is now `unknown`.
- No dependency, enum, table-schema, global constraint, target-selection, asset-management, event-time, or generic readiness-framework change is introduced.
