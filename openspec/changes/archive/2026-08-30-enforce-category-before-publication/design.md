## Context

See `proposal.md` for motivation and `specs/submission-promotion/spec.md` for required behavior. `category = unknown` is a valid incomplete classification for suggestions and pending moderation, but is not valid in the published catalogue.

The current public Flutter form represents no selection as a nullable category and omits it from the request; `submit-content` accepts the omitted field, omits the insert column, and PostgreSQL applies the existing `content_submissions.category = 'unknown'` default. This normal public workflow already satisfies the required pending semantics. An explicitly supplied public `"unknown"` remains outside the accepted wire contract. The separate admin create/update validator already accepts `unknown`. The current promotion RPC copies the stored enum value directly into `places` or `events`.

`public.promote_content_submission(bigint, text, uuid)`, defined only by `supabase/migrations/20260825170713_promote_content_submission.sql`, is `SECURITY INVOKER`, returns `(outcome text, target_type text, entity_id bigint)`, is executable only by `service_role`, locks the source row, resolves durable promotion links before status/readiness checks, and performs all target/media/link/status writes transactionally. The category rule must fit this boundary without changing those properties.

The current analyzer baseline is non-zero: repository-wide `flutter analyze` reports 20 informational diagnostics and none are in the Flutter files targeted by this change. Verification must therefore require zero diagnostics in touched authored Dart paths and no new or worsened repository-wide diagnostics, not unrelated lint cleanup.

## Goals / Non-Goals

**Goals:**

- Keep `unknown` valid for public suggestions, admin pending create/update/save, and rejection.
- Make the database promotion RPC authoritative for blocking unknown-category place and event publication.
- Propagate one explicit domain/API failure through the existing fail-closed backend contract and provide proactive Flutter UX.
- Preserve promotion idempotency, transactionality, security, target selection, assets, event-time semantics, and existing failure precedence.

**Non-Goals:**

- Remove `unknown`, change `public.content_category`, alter category defaults, or add table constraints.
- Expose `unknown` as a selectable public category or redesign public/admin category UI.
- Change `submit-content` production validation or make an explicitly supplied public `"unknown"` payload valid.
- Change shared admin create/update validation, rejection semantics, repository protocols, target-selection rules, event-time rules, or asset behavior.
- Introduce a generic readiness framework, new package, schema for published tables, or unrelated refactor.

## Decisions

### 1. Preserve unknown at every pre-publication boundary

Keep the enum, database defaults, public UI choices, and `submit-content` production code unchanged. When the public user leaves category unset, Flutter omits the field, validation normalizes the absent value to null, the handler omits the insert column, and PostgreSQL persists `unknown` through the existing default. Preserve this chain without adding `unknown` to the public validator's explicit accepted category values.

Where practical, focused regression coverage may prove the omitted/null request normalization used by this existing path. The handler spread and database default are unchanged and should be confirmed by targeted source/diff review rather than introducing a new handler harness for behavior this change does not modify.

Do not change `admin_submission_validation.ts`: its common create/update parser already accepts every enum value, including `unknown`. Do not add category readiness to save validation or rejection.

An explicitly supplied public `"unknown"` payload remains invalid. The requirement concerns the normal public workflow producing a pending row whose persisted category is `unknown`, not expansion of the public wire contract.

### 2. Add readiness to the existing promotion RPC without changing precedence

Create a new timestamped migration using `CREATE OR REPLACE FUNCTION public.promote_content_submission(bigint, text, uuid)`; do not edit the historical migration. Preserve the exact argument/return contract, `SECURITY INVOKER`, service-role-only execute ACL, row and city locks, transactionality, existing outcomes, target/date/city/asset checks, target inserts, media copying, durable linkage, handled metadata, and accepted transition.

Keep durable-link discovery before status and readiness checks so an already-linked submission returns `already_promoted` with its original target/id even if its source category is `unknown`. To avoid changing precedence among existing readiness failures, return `(category_required, null, null)` after current asset validation and immediately before the first target insert. This location is still before every target, media, durable-link, and submission-status mutation.

Alternative: enforce with a global constraint or in Flutter/Edge only. Rejected because a constraint breaks pending workflows, while client/API-only checks are bypassable by direct RPC callers.

### 3. Preserve fail-closed RPC result validation and expose HTTP 422

In `admin_submission_store.ts`, add `{ outcome: "category_required" }` to `PromoteStoreResult` and the explicit domain-failure switch. It must satisfy the existing invariant that `target_type` and `entity_id` are exactly null; malformed payloads and unknown outcomes remain `AdminSubmissionStoreError` failures.

In `index.ts`, map the recognized result to HTTP `422`, code `PROMOTION_CATEGORY_REQUIRED`, and stable message `The submission requires a category before publication.` This is a readiness failure, not a status conflict. The generated database types already expose `outcome` as text and need no contract change.

### 4. Keep the Flutter check narrow and ordered

Add a derived ViewModel property such as `hasPublishableCategory`, true only for a non-null category other than `ContentCategory.unknown`. In `_promote()`, run `_moderationGuardError()` first, then reject a non-publishable category locally before event-target temporal validation and before `repository.promote()`. This preserves common moderation precedence and existing event-time logic while giving direct command callers the same UX guard.

Leave `_save()`'s `null` to `ContentCategory.unknown` normalization unchanged and keep `_reject()` dependent only on the existing common moderation guard. Do not change `AdminContentSubmissionRepository.promote`; the concrete repository already preserves backend status/code/message in `AdminContentSubmissionApiException`.

### 5. Disable and explain only publication

For a pending editor, extend Publish's existing disabled predicate to `isDirty || operationRunning || !hasPublishableCategory`; leave Reject as `isDirty || operationRunning`. In the existing `Stato` section, show `Seleziona una categoria e salva prima di pubblicare.` only for a clean pending editor with an unset/unknown category. Existing dirty-state copy retains precedence after a concrete selection, so no auto-save or additional state machine is needed.

Map backend code `PROMOTION_CATEGORY_REQUIRED` to the same actionable Italian copy as defense in depth. Target selection and confirmation behavior remain unchanged.

### 6. Make failed-publication tests prove no side effects

Change only `createSubmission()` in `supabase/tests/submission_promotion_db_test.ts` from an `unknown` default to a concrete publication-ready category such as `nature`; production defaults and unrelated shared fixtures remain untouched. Replace `unknown category is a valid publication value` with separate place and event failures whose city, coordinates, dates, and at least one source asset are valid. The source asset makes the no-media-copy assertion meaningful.

For each target, snapshot the source row and source assets before promotion, then verify `category_required` with null payload, no target or target media, unchanged category/assets/`handled_by`/`handled_at`/`modified_at`, pending status, and null durable links. Extend an existing idempotent retry scenario by making an already-linked source category `unknown` before retry, then prove the original target/id still wins and no duplicate target/media is created. Retain concrete-category copy assertions.

## Risks / Trade-offs

- [The database emits the new outcome before the Edge Function understands it] → Deploy the store/result and HTTP mapping before or atomically with the migration; the mapping is backward-compatible before the outcome exists.
- [Moving the new category check changes which existing readiness error wins] → Place it after all current non-mutating readiness checks and immediately before target insertion.
- [Changing the promotion fixture default hides a production-default change] → Edit only the test helper and assert the schema/application defaults are untouched in diff review.
- [Flutter becomes an alternative authority] → Keep the RPC check mandatory and test direct RPC and handler paths; Flutter only avoids an obviously invalid request.
- [Category readiness accidentally disables public submission, rejection, or save] → Leave `submit-content` production code and shared moderation/save guards unchanged, and retain focused public-path, ViewModel/widget, and admin API regressions.
- [Scope grows into existing generated-type nullability or unrelated error-table coverage] → Leave pre-existing generated typing and unrelated mappings unchanged unless the narrow contract fails to compile; stop and update the artifacts before redesigning.

## Migration Plan

1. Add the admin store/result, API mapping, and Flutter handling with focused tests; preserve the existing public omitted-category path without changing `submit-content` production code.
2. Add and test the replacement RPC migration and promotion DB regressions; do not edit historical migrations.
3. Run focused Deno, local database, Flutter test/analyzer, and repository diff gates from `tasks.md`.
4. For production rollout, ensure the Edge Function version that recognizes `category_required` is active before or together with the database migration; Flutter can roll out independently because the backend remains authoritative.

Rollback requires a new forward migration that restores only the prior function body and re-verifies the same `SECURITY INVOKER` and service-role-only ACL; do not rewrite migration history. Apply that rollback migration only after explicitly accepting that direct/API promotion can again publish `unknown`. Edge/Flutter mappings may remain deployed because they add no schema state and the older RPC never emits the new outcome. No data repair is required for the forward change itself; if rollback is active long enough to permit unknown-category publication, audit published rows before claiming that no repair is needed.
