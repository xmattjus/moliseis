## Context

See `proposal.md` for motivation and the seven change-local delta specs for requirements. Planning was grounded in HEAD `e3e0461`, canonical `openspec/specs/`, relevant archived artifact conventions (read-only), migrations, Flutter code, and backend tests. All four existing capability names proposed by the dossier are real. Two additional canonical deltas are necessary beyond the dossier list. `event-temporal-integrity` currently allows both submission dates absent without qualification; its optional-interval requirement must restrict that case to false mode because true requires a start. Also, `content-submission-submit-orchestration` currently requires exactly fourteen request keys and UTC instants, which must explicitly accommodate the three new temporal input keys. All other `event-temporal-integrity` requirements remain unchanged: its chronological checks, Rome-year/day overlap, inclusive ranges, and start-based upcoming contract are prerequisites, not redesign targets.

Observed seams:

- `supabase/functions/_shared/submission_dates.ts` validates ISO-like dates and microsecond-aware ordering for both public and Admin validators. It currently accepts date-only strings in the legacy branch and preserves the original strings. Adding the new branch must not narrow that established contract.
- Public `submit-content/submission_validation.ts` feeds `submission_store.ts`, which invokes the service-role-only transactional `submit_content`. Its latest definition is in `20260908065810_harden_content_submission_server_idempotency.sql`; its last current parameter is `p_assets`.
- Latest promotion behavior is in `20260830144634_enforce_category_before_publication.sql`, superseding the earlier promotion migration. It reads the submission under a row lock, then copies start/end into an event. `20260929202015_harden_event_temporal_semantics.sql` already supplies the chronological CHECKs on both tables.
- Admin validation uses an exact `INPUT_KEYS` full-input contract. `admin_submission_store.ts` directly inserts/updates submissions and uses an explicit `SUBMISSION_SELECT` projection. This projection, returned rows, `AdminSubmission`, `AdminSubmissionInput`, and their Flutter mapper must also carry the flag.
- `lib/domain/core/event_time.dart` owns `EventCalendarDate`, `EventDateDraft`, and `EventTimePolicy`; enabled drafts currently need a resolved clock for persistence. Public and Admin ViewModels share that policy. Draft storage uses `ContentSubmissionDraftEntity` in `content_submission_draft_entry.dart`, with instants and `pendingStartCalendarDate` but no final civil-date field.
- `EventDto` → `event_dto_mapper.dart` → `EventEntity` → `event_entity_mapper.dart` → `Event` is the existing event path. DTO merge preserves local `isSaved`; the remote `events` table already has its `modified_at` update trigger.
- `import-external-events/import_logic.ts` owns `PreparedExternalEvent`, Rome conversion, and EventiMolise preparation. `index.ts` directly inserts prepared rows into `content_submissions`, not `submit_content`. EventiMolise currently includes an end only when both end date and end time exist.
- `event_formatted_date_time.dart` currently derives Rome dates but shows the start clock for same-day events. Event day membership, ObjectBox day/year filters, and search already use Rome overlap; upcoming uses a start-day window. The initial targeted scan found no event-expiration comparison against `now()` needing a helper.

`improve-admin-submission-editor-workflow` is an existing unimplemented change affecting the same Admin editor. This change adds temporal editing only; it does not require that separate Save/navigation/asset workflow. At execution, integrate with whichever editor version is actually present and preserve the other change's scope and artifacts.

## Goals / Non-Goals

**Goals:** Extend existing authoritative write and mapping boundaries with one explicit boolean mode; centralize backend normalization in the current temporal module; retain immutable editing/checkpoint/captured-attempt guarantees; prove the whole path and future adapter sufficiency.

**Non-Goals:** No new package, time-precision enum, `end_time_known`, half-open range conversion, generalized importer framework, source-specific live provider integration, cross-provider deduplication, publication editor, current-events Home feature, final-time UI/reminders, or version-management infrastructure. No automatic historical classification, complex SQL canonical-shape CHECK, corrective trigger, or speculative effective-end abstraction.

## Decisions

### 1. Use the dossier's closed semantic contract

`allDay`/`all_day` means unavailable meaningful initial time. It is not inferred from midnight or a missing final time. Single-day input without a final date uses Rome start-of-day with null end; an explicit final date uses the last microsecond of that Rome day, including when equal to the start day. Timed start plus final civil date remains false with the existing technical end-of-day bound. Final bounds serve queries without promising knowledge of the real end time.

These decisions are final. The name is retained for model continuity, while editor copy is “Senza orario”. Neither an enum nor a new domain class is warranted for this binary behavior. Inclusive persisted ends remain separate from the deferred half-open query design.

### 2. Extend the shared backend temporal boundary without weakening legacy input

Extend `submission_dates.ts` to receive the five temporal input values and return only `{ all_day, start_date, end_date }`. Public omission of `all_day` means false; a present non-boolean, including null, fails. In the false branch preserve existing ISO-like syntax, Gregorian checks, nullable pairing, original timed values, and fractional/microsecond ordering; civil fields must be absent/null. In the true branch require exact Gregorian `YYYY-MM-DD` initial date, allow absent/null or ordered final date, and require absent/null request timestamps. Reject mixed non-null representations before stores, including on replay.

Admin extends its complete explicit key set with the three fields; all five temporal keys are present, with nulls for unused fields. It does not become a PATCH contract. Non-event inputs use false with all date fields null. Civil fields are transport/editor inputs, not additional database date columns.

Use existing native `Intl` capabilities and the Rome conversion evidence in `import_logic.ts` to normalize civil-day boundaries inside the existing shared temporal module. Reuse/extract only the small conversion primitives actually needed by these writers; no new temporal library or importer framework. Do not simply serialize a JavaScript Date as an end-of-day bound: it would lose the required `.999999` precision. Preserve the final microsecond in the normalized string, obtaining the next civil day's boundary under the correct offset rather than adding a fixed 24 hours. Tests must agree with Flutter's existing Rome primitives on normal, spring, autumn, and year-boundary dates.

Importer adapters retain interpretation ownership. Date-only adapters call shared normalization; timed mixed-precision fixtures can materialize the final-day bound with the same primitives before entering the timed normalized path. This does not broaden the public timed grammar to accept mixed request formats. EventiMolise retains its current accepted-source and optional-end behavior, merely supplying explicit false and using the common normalized persistence shape. The real importer store must write the flag with the dates.

Alternative rejected: normalize civil dates in each Edge function or infer mode from timestamps. Both create inconsistent meanings at actual write boundaries.

### 3. Keep atomicity and compatibility at the current SQL boundaries

Create a new forward migration; never edit historical migrations. Add `all_day boolean NOT NULL DEFAULT false` to both tables and the minimal submission CHECK equivalent to `NOT all_day OR start_date IS NOT NULL`. Retain all existing temporal constraints; the event required-start column already covers the presence rule. Existing rows default to false without timestamp rewrites or heuristic backfill.

Extend `submit_content` with final `p_all_day boolean DEFAULT false` and insert it with the first submission commit. Replay returns the already committed row before new quota/assets and cannot mutate its mode/dates. Changing argument types/count creates a distinct SQL function identity: the migration must deliberately replace/remove the obsolete signature, preserve service-role-only grants on the new signature, avoid an ambiguous legacy overload, and refresh the PostgREST schema cache. Preserve security invoker/search path and all current ownership, quota, asset, and replay invariants.

A real service-role PostgREST smoke test using the old argument set is a mandatory gate. If optional-argument dispatch fails, use only the minimal compatible wrapper needed to preserve the old callable contract; do not preemptively create `submit_content_v2`. Both omitted false and explicit true must work through the actual boundary, and public database roles must remain denied.

Extend the latest `promote_content_submission` definition in the new migration to copy the flag from its existing locked snapshot into `events`; keep readiness checks, linkage, media, transaction, and already-promoted behavior. Admin reads/writes carry the normalized flag in their existing store operations. Regenerate `supabase/functions/_shared/database.types.ts` from the migrated local schema using the CLI generation workflow, retaining repository handling of nullable RPC arguments.

Alternative rejected: a second public persistence API, separate flag update, complex canonical timestamp CHECK, or correction trigger. None is necessary and separate writes would violate atomicity.

### 4. Propagate through existing models and immutable draft policy

Add a non-null `bool allDay` with historical/default false semantics to the appropriate Event/ContentSubmission, DTO/entity, and Admin model contracts. Extend constructors, copies, equality, JSON/generator inputs, initial mapping, merge, and entity-to-domain mapping. Wire mappers choose the representation from the immutable content captured by the existing attempt: true sends Rome civil dates and null timestamps; false sends existing UTC instants and null civil fields. Never serialize all-day technical midnight as a meaningful timestamp request.

Extend `EventDateDraft` with `allDay` and `endCalendarDate` and reuse `EventTimePolicy` for hydration, validation, editing, and materialization. All-day needs a civil start, not a clock. Enabling the mode preserves both civil dates and materializes bounds; disabling it preserves dates, clears resolved start, and requires a newly chosen time. Changing civil dates must rematerialize valid all-day bounds. Selecting a new timed clock reconstructs the retained final-day end. Disabled event state has false and no persistible date values. Preserve current ambiguous/nonexistent Rome wall-time validation for timed edits.

Checkpoint and recovery must handle the intermediate false/unresolved-start state with a retained final civil date. For resolved drafts derive `endCalendarDate` from `endDate` during hydration, avoiding duplicate persisted information. For the intermediate unresolved state, the existing schema has neither a usable end instant nor a place for that civil date: add a narrow optional pending-final-civil-date storage property in `ContentSubmissionDraftEntity`, analogous to `pendingStartCalendarDate`, only where the instant cannot represent it. Do not persist an end-without-start workaround. This is a necessary storage adaptation to the closed preservation requirement, not a new architecture decision.

Include both new draft values in equality/hash, dirty state, checkpoint snapshots, and immutable submission capture. Missing allDay defaults to false only for otherwise supported historical drafts; missing/invalid client identity and unsupported pre-schema shapes retain their current safe fresh-session fallback. Recovery remains non-writing.

Alternative rejected: restore the previous time, use technical midnight when toggling off, lose the end day, or duplicate the final civil date for every resolved draft.

### 5. Evolve ObjectBox and reuse synchronization

Change entity inputs, then run `dart run build_runner build --delete-conflicting-outputs`. Inspect `lib/generated/objectbox-model.json`, `objectbox.g.dart`, and dart_mappable diffs: preserve existing entity/property UIDs and retain only intentional generated additions, including the draft's new properties. Do not hand-edit generated output.

Prove reopening an actual prior-model cache, including a previously saved event, and a prior supported draft. Historical boolean values must be false. DTO merge and entity copies must retain `isSaved`. Prove a remote flag-only change advances `modified_at` and is accepted through the existing sync replacement boundary; no new sync mechanism is introduced.

Before editing the DTO, test the decoder from the currently published release with an extra remote key. HEAD alone is not evidence of the deployed release. Identify the release artifact/commit and record it; if unavailable, leave the gate incomplete. A decoder incompatibility requires the minimum proven crash-prevention accommodation before rollout, without version-routing or forced-update infrastructure. Semantic midnight display on old clients is explicitly accepted.

### 6. Extend editor and display surfaces, preserving discovery

Public `content_submission_view_model.dart`/`content_submission_fields.dart` and Admin `admin_submission_editor_view_model.dart`/`admin_submission_editor_screen.dart` apply the shared draft transitions and hide/disable the meaningful-start clock requirement in true mode. Hydrate Admin read/create/update responses with their stored mode. Keep Command, Provider, current lifecycle guards, pending-only moderation, and asset behavior.

Update `lib/ui/event/widgets/components/event_formatted_date_time.dart` and audit other direct start-clock renderers so true mode uses Rome dates without a time label. Keep the current multi-day/final-date presentation and false-mode rendering. Do not introduce final-time copy.

Existing `EventViewModel.isEventOnDay`, `_getByDateRange`, `ObjectBoxConditions.visibleEventInCurrentYear`, and search's in-memory annual predicate already express day/year overlap. Add all-day regression fixtures through actual repository/search consumers without rewriting these predicates. Sorting and `getNextEventIds` remain start-based. Recheck actual current-time expiration consumers during implementation; the initial scan found none, so introduce no helper unless a real consumer fails single-day membership. If found, correct it minimally in its owning layer; do not change upcoming semantics or introduce an expression index/general effective-end API.

## Risks / Trade-offs

- [An optional RPC parameter leaves an ambiguous old overload or loses grants] → Replace signatures deliberately and test actual PostgREST dispatch, omitted/default behavior, and anonymous/authenticated denial before deploying Edge callers.
- [Backend Date serialization truncates the final bound or assumes 24-hour days] → Assert exact microsecond strings and 23/25-hour Rome DST boundaries against existing Flutter primitives.
- [Checkpoint loses final civil date while timed start is unresolved] → Persist only the necessary pending civil-date projection and exercise toggle/checkpoint/restart/new-clock/submit.
- [Generated model alters UIDs or flag merge resets saved state] → Inspect generated diffs, reopen a prior-schema store, and exercise real cache merge/sync with saved events.
- [Published decoder behavior is unverified] → Gate deployment on identified-release decoder evidence; accept old semantic display limitations only after technical compatibility is proven.
- [Adjacent Admin planning changes the editor during implementation] → Integrate the temporal seam against execution HEAD without implementing or rewriting the other change.
- [A real expiration consumer misreads null-end all-day start] → Gate on a focused consumer audit and regression; add only an evidenced local correction.

## Migration Plan

1. Implement and verify the shared temporal grammar/normalizer, preserving legacy accepted forms. Capture the actual released-decoder evidence before DTO changes.
2. Apply the additive local migration and verify database defaults/constraints, RPC compatibility/grants/cache refresh, replay, promotion, and generated database types. Update public/Admin backend contracts together with the Admin client because its full-input contract is intentionally extended.
3. Extend Flutter models, draft storage/policy, mappings, generator inputs, editors, and rendering. Reopen prior caches and exercise full captured submission → promotion → remote fetch → ObjectBox → display behavior.
4. Extend prepared importer persistence and prove the four adapter fixture shapes; keep live EventiMolise behavior and dedup unchanged.
5. Complete focused/full affected verification and the technical gates in `tasks.md`. For deployment: database migration first, then compatible public/backend/Admin releases, then Flutter, then importer; later providers remain separate changes. No adoption-percentage gate is required.
6. For rollback stop producing new date-only events before reverting writers/UI. Retain additive columns and already stored mode information; do not silently rewrite new all-day records or drop constraints/data. A previous Flutter release may display midnight but must remain technically compatible under the decoder gate. Destructive schema rollback would require a separate migration and review.

There are no reopened product or architecture decisions. Optional RPC dispatch, released-decoder tolerance, actual expiration-consumer behavior, and generated-model integrity are technical gates with bounded remedies specified above.
