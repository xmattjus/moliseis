## Context

See `proposal.md` for motivation and the four delta specs for required behavior. The implementation baseline is exactly `366bda6f294ee219a88106a700208b4708e21f48`, which contains completed Subplans 1–4 and synchronized main specs. The current Flutter repository already sends a canonical UUID-v4-compatible `client_submission_id`, validates only a positive `submission_id`, and intentionally keeps `Result<void>`; the current Edge parser ignores the identity and performs quota read/update, submission insert, and asset RPC as separate transactions. The database has no client identity column or submit RPC, RLS denies direct public writes, and privileged Edge code uses a service-role client.

The implementation/apply gate is repository-local: every in-repository production caller targeted by this change must send the canonical identity, and the current Flutter repository contract must accept both HTTP 201 created and HTTP 200 replay acknowledgements while preserving `Result<void>`. The verified caller satisfies those conditions, so this design makes the identity required at `submit-content`; if either repository contract is no longer true when implementation begins, implementation must stop and the OpenSpec must be reconciled.

Released-client compatibility is a separate production deployment gate. Before deploying a strict Edge Function that requires the field, release/support policy must confirm that every still-supported deployed client able to call the endpoint sends it. An incompatible historical client blocks only that Edge deployment, not local implementation, additive database/RPC work, or verification. Prefer releasing a compatible Flutter build and making it the minimum supported production version before strict Edge rollout. If simultaneous support for pre-Subplan-4 clients later proves necessary, define its temporary backward-compatibility semantics and tests in a separately reviewed OpenSpec rollout change; do not add a speculative optional-key or legacy non-idempotent branch here.

## Goals / Non-Goals

**Goals:**

- Resolve response-loss ambiguity through a durable user-scoped idempotency key.
- Make quota, content, and asset persistence atomic and concurrency safe.
- Preserve every Subplan 1–4 client, Command, Provider, ViewModel, Cloudinary, route, and local-finalization contract.
- Add deterministic database and Edge coverage for concurrency, rollback, replay, authorization, and response mapping.

**Non-Goals:**

- No automatic client retry, background work, persistent outbox, multi-draft support, or payload-version protocol.
- No Cloudinary deletion/rollback, parallel upload, or new remote media lifecycle.
- No Admin editor/promotion redesign, RLS relaxation, generic repository/use-case layer, package, or broad Edge framework.
- No attempt to make local staged cleanup stronger than its existing best-effort contract.

## Decisions

### 1. Extend `content_submissions` rather than add an idempotency ledger

Add nullable `client_submission_id uuid` to `public.content_submissions`, a canonical-v4 check for non-null values, and user-scoped uniqueness on `(user_id, client_submission_id)`. Null preserves existing rows and Admin/import flows, while the hardened public Edge path always supplies a value. Keeping the key on the owned resource makes replay lookup, moderation-state preservation, and lifecycle inspection direct and avoids a second table whose retention and referential lifecycle would need new policy.

Alternative: a separate request ledger could retain keys after submission deletion and store request hashes. It is rejected because public deletion is currently unavailable, first-commit-wins is the required semantic, and the extra lifecycle is not needed for this subplan.

### 2. Use one service-role-only `security invoker` RPC as the transaction boundary

Add `public.submit_content(...) returns table(outcome text, submission_id bigint)`. It receives the authenticated `user_id`, required UUID key, every currently validated content field, and JSON assets as explicit parameters. It is `security invoker`, references relations explicitly, is revoked from `public`, `anon`, and `authenticated`, and is granted only to `service_role`, matching the existing promotion and asset-function pattern. The Edge Function authenticates and fully validates the request first, then calls it through the existing admin client. The RPC maps a null public category to the existing `unknown` database value; all other nullable fields remain null, preserving the current handler's omit-column/default behavior without changing the public wire envelope.

The RPC owns quota arbitration, first-write persistence, existing `add_submission_assets` invocation, and outcome selection in one PostgreSQL transaction. Any raised database error rolls the whole invocation back. A single RPC is chosen because independent `supabase-js` table/RPC calls cannot provide one database transaction through the current client boundary. Supabase recommends database functions for data-intensive database operations and `security invoker` by default; the existing repository already restricts function execution with explicit revoke/grant statements.

### 3. Serialize per-user quota and replay decisions through the rate-limit row

The RPC captures one transaction timestamp and first looks up the committed `(user_id, client_submission_id)` key without mutating quota. An existing key returns `replayed` immediately. For a key not yet visible, it inserts a `submission_rate_limits` row with count zero and the transaction timestamp using `INSERT ... ON CONFLICT DO NOTHING`, locks that user's row `FOR UPDATE`, and rechecks the key under the lock. This second lookup resolves a same-key transaction that committed while the caller waited.

Only a still-new key reaches the quota decision. The function preserves the current fixed-window policy exactly: a row whose `window_started_at` is later than the transaction timestamp minus 24 hours is active; a row at or before that boundary is reset to count zero and the transaction timestamp. An active count of five returns `rate_limited`; otherwise the function inserts content/assets and writes the incremented count in the same transaction.

This order makes same-key races consume one slot and different-key races unable to overrun the fifth slot. The lock is user-scoped, so unrelated users do not block one another. A unique constraint remains the final duplicate invariant even if future callers bypass the expected ordering.

Alternative: rely only on `INSERT ... ON CONFLICT`. It prevents duplicate rows but permits both racing requests to touch quota before conflict resolution and does not close the existing read/upsert lost-update window.

### 4. First commit wins; replay never compares or updates payload

Once a key commits, subsequent otherwise-valid requests by that user return its row ID regardless of later body differences and do not rewrite content/assets. Authentication, identity validation, and the complete existing public payload validation still run before the store/RPC boundary; possession of a committed key is never a malformed-request bypass. This matches Subplan 4's logical-session ownership: edits made after an actual but unobserved success are late same-session edits and are retired when the replay acknowledgement is recovered. It also prevents a replay from mutating content already under moderation.

Alternative: store and compare a payload hash, returning conflict for changed retries. It is rejected for this subplan because the client has no recovery state for such a conflict, the existing session contract defines one stable identity across retryable failures, and adding canonical hashing/versioning would broaden both protocol and UI work. The first-write-wins trade-off must be covered explicitly in specs and tests.

### 5. Preserve the positive acknowledgement contract

The database returns only `created`, `replayed`, or `rate_limited` plus a nullable/positive ID as appropriate. The Edge Function maps:

- `created` → HTTP 201 and `{submission_id, replayed: false}`;
- `replayed` → HTTP 200 and `{submission_id, replayed: true}`;
- `rate_limited` → HTTP 429 with the existing `RATE_LIMIT_EXCEEDED` code and `Maximum 5 submissions per 24 hours exceeded` message;
- RPC errors or malformed/unexpected rows → stable 500 responses without leaking database details.

Subplan 4 already permits additional response keys and accepts any positive integer ID, so Flutter production code remains unchanged. There is no hidden retry; users or existing progress controls initiate the next attempt, and the same local identity reaches replay.

### 6. Refactor only the Edge seam needed for deterministic tests

Follow the established `admin-content-submissions` and `prepare-cloudinary-upload` pattern: expose a small handler factory with injectable authentication/store dependencies and place the privileged RPC call behind one focused submission-store interface/implementation. Keep validation in `submission_validation.ts`. This enables handler tests without environment variables or live credentials and avoids moving domain policy into widgets or Flutter repositories.

The parser adds `client_submission_id` to `ValidatedContentSubmission`, validates the exact canonical lowercase v4 expression used by `ContentSubmissionDraft`, and rejects missing/invalid values before store construction. The existing valid-request fixture gains that required field so all prior parser cases continue exercising the complete envelope. The store forwards an exact allowlist of parsed values and server-derived user ID; the RPC alone converts null category to `unknown` for persistence.

### 7. Regenerate Supabase types and verify at three layers

After `supabase db reset --local`, regenerate `_shared/database.types.ts` from stdout with `supabase gen types typescript --local` rather than hand-editing it. Add parser and handler/store unit tests, a real local Postgres suite for transactional/concurrent invariants, and one Flutter repository regression accepting a 200 replay envelope. Run `deno check` on the changed production entry point in addition to formatting/tests, and re-run the complete existing Content Submission ViewModel and routing/widget suites to prove no predecessor behavior was weakened.

## Risks / Trade-offs

- **Supported released clients may omit the key** → Treat this as a strict Edge deployment blocker, not an implementation blocker. Wait until a compatible build is the minimum supported production version, or create a separately reviewed rollout change if temporary coexistence is proven necessary; do not silently weaken this design with an optional-key path.
- **First-write-wins can discard edits made after a lost acknowledgement** → This is consistent with Subplan 4's late same-session success semantics; make it explicit in tests and do not overwrite the committed row.
- **A long database call holds one user's quota-row lock** → Keep the RPC database-only, perform no network work inside it, and lock only after Edge authentication/validation and Cloudinary upload have completed.
- **Unexpected RPC outcomes could be mistaken for success** → Accept only one known row with a positive safe integer ID; map everything else to a stable failure and leave local state retryable.
- **Generated types can drift from migrations** → Generate from a reset local Supabase stack and review that only the new column/function signatures change.
- **Rollback after Edge deployment can reintroduce duplicate risk** → Deploy migration before Edge; rollback Edge first only if necessary, keep the additive schema/function in place, and do not drop the identity column/constraint while keyed rows exist.

## Migration Plan

1. Verify the exact baseline, clean/understood worktree, existing four strict OpenSpec validations, focused Flutter tests, and current Deno validation tests. Confirm every targeted in-repository production caller sends canonical `client_submission_id` and the current Flutter repository contract accepts both created and replay acknowledgements; stop implementation only if that repository contract is false.
2. Add the forward-only migration and database integration suite; reset/start local Supabase, regenerate types, and prove sequential/concurrent/rollback/quota behavior before touching the Edge handler. This additive database/RPC work can be implemented and tested independently of released-client rollout state.
3. Add parser/store/handler changes and unit tests while retaining the response envelope consumed by Flutter.
4. Run Deno formatting/tests, database tests, focused Flutter tests, complete Flutter tests/analyze, strict OpenSpec validation, and final diff/scope review.
5. Treat production rollout separately from implementation completion. The additive database migration/RPC may be deployed first, but do not deploy the strict Edge Function until every still-supported released client that can call it sends the canonical field. No additional Flutter production implementation is required for builds from the current Subplan-4-compatible repository; if published store builds predate that contract, release a compatible build and make it the minimum supported production version before strict Edge rollout, or create a separately reviewed rollout change if temporary backward compatibility is actually required.

Rollback is Edge-first: restore the previous handler while leaving the additive column, uniqueness, and RPC in place. Dropping the database additions is a separate reviewed migration only after confirming no keyed rows or deployed callers depend on them.
