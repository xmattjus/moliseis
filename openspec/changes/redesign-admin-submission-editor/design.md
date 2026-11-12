# Design

## Context

See `proposal.md` for motivation and scope. This Intervention C design was explicitly authorized for implementation after review of planning commit `bb635bbd6bfde9986770e4bbecf2764aea19fdb0`.

### Planning baseline and preserved ownership

- `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart` composes a `CustomScrollView`: recovery controls, shared content fields, location, photos, contributor identity, status/source/candidates/merge groups, moderation and finally Save. The app bar names the editor operation rather than the content. Source values and merge maps are rendered as text; publication/rejection sit alongside contextual linking and preview controls. Final-state form/location wrappers use opacity 0.55 and prevent pointer/focus interaction.
- `ContentSubmissionFields` owns shared field presentation and validation, receives controlled event-date state and `hydrationRevision`, and preserves private text masking. It must remain the single content form; category, municipality, name, rich description, event discriminator, all-day mode and dates remain available with existing semantics.
- `AdminSubmissionLocationEditor` owns its local Map/Coordinates display mode and coordinate controllers. Its coordinate Form stays mounted during Map/Coordinates switching through Offstage; this does not retain the entire location widget if its lazy sliver child is disposed. It already calls `showGeoMapLocationPicker()`, captures the activation-bound callback before awaiting, ignores cancellation and identical-point confirmation, and preserves raw draft values. No Intervention B implementation is needed.
- Shared `ContentSubmissionAddAssetButton` and `ContentSubmissionAssetListItem` render photo controls. The Screen/owner provides staged files, confirmed associations, capacity, progress, errors and picker cancellation. The current remove overlay has a 24 logical-pixel constrained target: accessibility needs a compatible presentation adjustment, not replacement of the media workflow.
- `AdminSubmissionRecoveryPanel` displays coherent local/remote field differences and delegates choices; it does not persist. It already adapts comparison columns to available width.
- `AdminSubmissionEditorViewModel` owns current fields, exact authority, command reservations, source acknowledgement, candidate/target selection, preview invalidation and admission. `isDirty` includes unconfirmed fields, staged work and unresolved write intent; it differs from local exit dirtiness. `canRequest*` alone is not a replacement for the Screen's dirty/category checks or request-time validation.
- `AdminSubmissionEditorRoute`, router exit policy and application-owned draft/save session own route restoration and exit decisions. `_save` requires both Form states and temporal validation, treats an absent Form as false without feedback, and only then admits Save synchronously and pushes Save Progress. Existing `validate: false` captured-save continuation intentionally skips current-form validation. Save keeps the editor open; qualifying moderation terminals close only their owning editor. Existing publish/reject dialogs capture revisions and revoke covered/obsolete dialog authority.

The canonical contracts remain `admin-submission-editor`, `admin-draft-persistence`, `admin-local-asset-staging`, `admin-submission-save-idempotency`, `external-event-provenance-moderation` and `submission-promotion`. Shared field behavior also follows `content-submission-draft-persistence`, `content-submission-navigation-lifecycle`, the event temporal specifications and `editor-picker-restoration`. The sole delta adds presentation concerns to `admin-submission-editor`; it replaces none of those safeguards.

## Goals / Non-Goals

**Goals:** Make content and the next allowed decision readable at any scroll position; reduce incidental detail; preserve command, form and route ownership while using existing design tokens.

**Non-Goals:** Split or redesign the ViewModel/session, create a reusable workspace framework, introduce a diff engine, alter shared field order globally, change backend/provenance data availability or redesign Save Progress. Exclusions in `proposal.md` apply throughout.

## Decisions

### 1. Lead with a summary, retain the shared form

| Current presentation | Target presentation |
| --- | --- |
| Generic editor title; status after photos | Content name, municipality, event/place type and status at the start; explicit empty placeholders |
| Recovery mixed into the opening form | Urgent noncollapsed recovery summary and existing comparison/choices before normal content when necessary |
| Shared form, location, photos | Shared form, then a cohesive photos and location section retaining both existing components |
| Contributor details before moderation | Secondary disclosure for contributor email, timestamps and technical identifiers already available |
| Raw source/merge maps with decisions | Contextual verification emphasizing consequential groups and explicit target identity |
| Moderation and final Save in scroll | One persistent decision area; group-specific Keep Current remains with its evidence |

The summary reads current authorized draft values and does not add controllers or editable duplicates. Differentiate preserved local fields from observed remote final status in recovery. Provenance has a concise always-visible external-source label using available model evidence (external submission and linked Event); do not invent a provider name or URL absent from the detail model. Complete existing source snapshots, technical record/hash/version data and field values can be disclosed without fetching new contracts.

Use secondary disclosure for incidental metadata and unchanged comparison details, not warnings or required choices. Moving private text requires retaining or adding the corresponding `SentryMask`, including classified unpublished identity in the new summary; apply the selective classification below rather than masking the whole workspace. Do not infer that imported content or a technical disclosure is safe for telemetry.

### 2. One action composition adapts to actual space

Compact/medium structure: editor app bar and identity; scrollable content/verification/details; a bottom decision surface outside that scroll. Include primary action and blocker/status copy, with secondary decisions in a labeled expandable action surface when they cannot fit. An expanded secondary surface scrolls within the available viewport and exposes all applicable actions without requiring form scrolling. It has one instance of each decision control. Target/search inputs remain in verification; Keep Current remains next to its group. No FAB or duplicate scroll-end Save.

Expanded structure: constrained content column beside a persistent, bounded moderation panel with status, blocker, primary and secondary decisions. The decision/status and concise risk region remain fixed; only alternative actions and contextual guidance scroll independently, with primary-controller inheritance disabled for that internal scroll. Verification values stay in the content column rather than stretching the side panel into a second form. In both layouts, keep the current overwrite-count warning and "Esamina sovrascritture" alongside Apply outside secondary-action disclosure and any independently scrolling secondary controls, so they remain visible when comparison groups are off-screen; do not duplicate complete conflict values there.

When short viewports, keyboard insets or enlarged text cannot accommodate both full risk messages and usable actions, retain a labeled, always-visible combined risk summary identifying the overwrite count and newer source. Its immediate menu offers "Esamina sovrascritture" and "Esamina fonte aggiornata" independently of "Altre azioni". Neither navigation acknowledges source revisions or adds an Apply gate. Allocate remaining space to secondary actions without a rigid flex ratio, preserving a complete 48-pixel target. Place compact decisions in the Scaffold footer so Snackbars do not obscure them.

Use the existing Material window-size/spacing conventions (`windowSizeClass`, with compact <600, medium <840, expanded <1200) as context, and local layout constraints for the actual decision. Start side-panel eligibility at expanded width only when a readable content column, gap and action panel fit; fall back if scaled labels or host constraints cannot fit. Do not apply an unrelated `ResponsiveScaffold` map/bottom-sheet composition wholesale. Exact width caps and spacing are presentation tuning, not new global breakpoints.

Respect bottom SafeArea, keyboard insets and existing navigation surfaces. The compact decision surface stays reachable above the keyboard; expanded secondary actions must not consume the whole editor height. Wrap/stack labels and let content scroll so the active field and its error can be brought into view. Reparenting must preserve shared field/controller identity, form validation, current text and selection; resizing is never a hydration event. Do not mount two copies of a form or action surface to implement responsiveness.

### Stable forms and reachable validation

The current content/location sections are children of `SliverList.list`. The inspected Flutter SDK's `SliverChildDelegate` lifecycle documents lazy creation/destruction even for an explicit widget list; automatic keep-alive depends on descendant requests such as focused text. A first delegate child is laid out for extent estimation, but location follows a heading and content can follow recovery controls. Neither keys nor inner Offstage guarantee both Form states throughout scrolling. Existing Map-mode and scroll-to-Save tests show those particular paths work, not arbitrary viewport/keyboard states. This is a verified planning gap and lifecycle risk, not a reproduced claim that every current Save fails.

Keep the two finite form-bearing sections as stable mounted subtrees in the same content scroll host, using ordinary non-lazy box/sliver composition (for example stable `SliverToBoxAdapter` sections). Change the placement of the decision surface around that host without moving the forms between conditional compact/expanded trees. Preserve the existing form keys, controllers, hydration rules, rich-text selection and location mode; Offstage continues to preserve coordinate validation across modes. No second form tree, duplicate controllers, global keep-alive framework or new validation layer is needed. Other large lists need not be retained eagerly.

Ordinary Save/Create validates both existing forms and temporal state before admission regardless of visibility. A missing Form is an unavailable validation state, never permission to save or a silent no-op. Show a visible actionable validation summary and use the same feature-local reveal/focus approach to reach the first invalid field/message on explicit Save or error-action selection. If Map mode hides an invalid coordinate field, the error action reveals Coordinates for correction; retain the Map-mode invalid-draft hint. Respect keyboard/action insets and make long messages readable. Never reset or auto-scroll on ordinary rebuild/resize. Validation failure starts neither Save nor Progress; success retains the existing single admission followed by Progress. Resume Captured Save continues through the existing `validate: false` path and its captured-work guards, unaffected by new current-form feedback.

### 3. Priority changes emphasis, never eligibility

Apply running and recovery precedence first, then final read-only state, then new/dirty work. For clean pending work, an explicit eligible Event link target or external update comparison takes precedence over the publication rows below. A primary candidate remains disabled when its existing guard refuses; show the reason and a route to its prerequisite. Do not manufacture a mutation merely to keep a filled button enabled. Contextual prerequisites such as choosing a target or category may be emphasized as navigation/focus affordances without executing commands. UI copy remains consistent with the app's Italian interface; planning artifacts are English.

| State | Dominant presentation | Secondary/contextual actions and guard preservation |
| --- | --- | --- |
| Initial detail load | Loading state | Existing loading/return behavior; no premature moderation |
| Running command | Named progress for that operation | Retain reservations, repeat-tap refusal and current field-lock policy; Save's captured-work semantics still allow newer typing |
| Recovery, unknown outcome or pending checkpoint | Current recovery explanation and the applicable next recovery action | Existing read-back, reload, resume captured Save, settlement, checkpoint and return; compare choices remain with `AdminSubmissionRecoveryPanel`. If multiple choices are equally valid, explain them without preselecting a destructive resolution |
| New submission | Create submission | Local photos and content editing; no moderation before persistence; ordinary validation applies |
| Pending, dirty/unconfirmed | Save changes | Explain saved-work requirement; preserve dirty guards on Publish, Reject, Link, Preview and Apply |
| Clean pending, concrete category, ordinary or external create | Publish as event/place matching current type | Save and Reject; human Event submissions and external create proposals retain existing target search/selection and Link eligibility. Do not invent an event/place toggle at publication time |
| Clean pending, category missing | Disabled Publish with category guidance | Locate category in existing form; Save and eligible Reject remain. Missing category alone does not block Link or Reject |
| Human Event or external create, deliberately selected eligible link target | Link to selected Event | Publish remains a separate alternative if eligible; identify target and existing linking semantics, no canonical field/media overwrite |
| External update, no current preview | Preview update, or target-selection prerequisite if missing | Search and manual ID entry, Link and Reject retain current availability; no create-publication control for update mode |
| External update, current valid preview | Apply update | Preview, Link and Reject where eligible; Keep Current stays per group and keeps its existing copy-save-preview workflow |
| Accepted/rejected | Final status/read-only summary | Existing publication linkage, metadata and content review; no Save/moderation controls. Retained local recovery actions remain separately eligible |
| Terminal operation failure | Specific error plus original action or required recovery step | Preserve fields/progress; source/token conflict requires the existing refresh/preview path, not a new retry policy |

Preserve four distinct questions: (1) is this action offered in the current workflow, (2) are its interactive prerequisites satisfied, (3) can the existing command be admitted now, and (4) will the backend accept it? The first three determine presentation using current owner state and existing request guards; the fourth remains server-authoritative. `canRequest*` mostly reflects admission, not all structural UI prerequisites. Do not replace the first three with a permission engine or reproduce server validation.

In the current Screen, linking/search/target controls are nested under Pending and `startDate != null`; Link additionally needs clean work, `canRequestLink` and a selected target. `setEventEnabled`/temporal setters invalidate preview/candidates but retain `_targetEventId`; ordinary Save calls `_publishDetail` without `replaceSelection`, so Event-to-Place Save can retain that selection. Preserve the non-null start prerequisite explicitly when moving actions; a retained ID cannot make Place-like content Link-ready. Missing/unresolved starts do not offer Link as an eligible primary action. Other invalid temporal input retains existing validation/request/backend handling rather than new blanket guards; a non-null instant is not proof of all temporal validity. Request-time start/dirty/activation checks still protect stale callbacks and prevent a repository Link after start removal. Category alone blocks publication, not otherwise eligible Reject or Link. Preserve external create/update distinctions, Preview versus Apply, original group-specific Keep Current, normal Save versus captured continuation, and existing confirmations/revision checks.

Save/Publish remain separate. Forward existing callbacks, activation tokens, request guards, confirmation dialogs, current revision checks and error mapping. Link/Preview/Apply are not newly given Publish/Reject confirmation semantics. The matrix describes priority, not backend readiness: coordinate, city, temporal, asset and category checks remain at their current validation boundaries, including actionable backend failures.

### 4. Reconciliation is contextual, complete and server-described

Use existing `AdminEventMergePreview.groups` and `apply`, `overwrite`, `providerChanged`, `moderatorChanged` flags. Show overwrite groups first, then other consequential groups, then unchanged groups; retain original group objects for Keep Current. Use clear labels for proposed moderated/current Event values, and base/source details. Overwrite warnings and proposed/current values are expanded by default and cannot be hidden behind a disclosure. Long text wraps; a full-value surface remains reachable, including rich-description structure where needed to explain formatting differences. Do not replace opaque values with a lossy one-line summary.

For a valid current preview, derive the overwrite count directly from its existing groups. Show an explicit accessible warning identifying that count and a labeled "Esamina sovrascritture" action in the persistent decision area. On explicit selection, reveal the current preview's first overwrite group with its warning and complete proposed moderated/current destination values available for reading without secondary disclosure; long values remain scrollable in full. Use a small Screen-local target and ordinary Flutter scrolling/widget composition, not a generalized navigation framework or new application state. Keep original group objects and ViewModel authority unchanged.

Bind navigation to the rendered preview and activation, recheck that both remain current before scrolling, and discard obsolete targets on invalidation/replacement. Recompute the warning/count and first target for a replacement; remove both warning and action when no valid preview contains overwrites. Resolve the target against the current layout after compact/expanded changes, respecting the persistent area's insets and accessible focus behavior. Layout changes and preview notifications never initiate scrolling by themselves. This affordance invokes neither Apply nor Keep Current, adds no mandatory dialog, per-group read/acknowledgement state or visit requirement, and leaves `canRequestApply` and all existing admission/invalidation rules unchanged.

When `externalEvent.stale` is true, keep an accessible newer-source indicator and "Esamina fonte aggiornata" beside the resolution actions in both layouts even while source details are off-screen. Reuse the small feature-local reveal/focus approach to reach current-source evidence and the existing explicit checkbox; do not duplicate the snapshot in the action area. Derive presentation from the current external detail, displayed hash and activation, not new source-version state. Update/remove the indicator and target on source reload/change or activation replacement; old callbacks cannot reveal stale private evidence. Keep complete source values accessible, preserve acknowledgement binding to the displayed hash and SOURCE_CHANGED refresh-and-review. Navigation neither mutates nor selects the checkbox, and copy explains that resolving the proposal alone does not acknowledge newer revisions. No mandatory visit, reading, acknowledgement or additional dialog is introduced. Distinguish acknowledgement from Save and from Apply selection; retain the existing complete-revision rejection explanation and ignore-future-source checkbox in Reject confirmation. Preserve advisory pending warnings, candidate search errors, selected Event identity and manual target entry. No client-side merge computation, automatic target choice or provider normalization is added.

Recovery comparison is separate from source reconciliation: accepting remote or keeping local changes the existing baselines only as already defined. Keep checkpoint-not-durable copy, staged association uncertainty and invalid progress notices visible. No disclosure or layout change triggers persistence or restores revoked evidence.

### 5. Minimal boundaries and shared accessibility

Keep the Screen as the composition/effect owner. Extract at most cohesive feature-local identity/details, verification and decision sections when needed for readability; these receive values and bound callbacks, not repositories or new command owners. Do not mandate a file per subsection, a CTA engine, a new state model or a shared workspace abstraction. No ViewModel split is needed.

Reuse `ContentSubmissionFields` unchanged by default. Remove outer global opacity, retain focus/pointer locks, add explicit read-only status, and prevent category/date/map interactions in final states. If a shared field's native disabled visuals defeat normal contrast, use a narrowly justified optional presentation input with editable defaults, not a parallel Admin form. Preserve `AdminSubmissionLocationEditor` validation/controller ownership and the existing map helper; a narrow local presentation hook may reveal its existing Coordinates fields from the error summary. This adds no picker functionality or routing abstraction.

The photo removal overlay's current 24-pixel target justifies a small optional presentation sizing input on `ContentSubmissionAssetListItem` if the existing caller cannot enlarge the hit area safely. Admin requests at least 48 pixels; public callers retain defaults and deletion/upload logic. Keep the visible icon appropriately sized and adjust photo spacing to avoid overlapping hit areas. Verify the compatible shared seam without expanding into a public editor redesign.

Use theme `ColorScheme` roles and existing shapes/spacing. Fraunces remains display/headline/titleLarge, Lexend the other roles per `app-typography`; use semantic styles rather than per-widget font declarations. Avoid decorative cards around every field, new colors, animation dependencies and fixed-height action rows. Provide headings, meaningful labels, expanded-state semantics, keyboard activation, logical reading/focus traversal and non-color status/error cues. Verify minimum targets, light/dark contrast and large text with the actual rendered controls.

### Selective Replay boundaries across moved surfaces

`lib/main.dart` uses `maskAllText = false` and `maskAllImages = false`; follow `session-replay-privacy` without global changes. The current Screen masks contributor identity, moderated preview values and pending warning text; shared form/location, recovery comparison and photo widgets also provide masks. Current source/base/current text is not uniformly wrapped, so copying existing wrappers alone does not establish privacy for every restructured surface. Classify rendered values before placing boundaries, including disclosure contents and any duplicate summary/error text.

Protect original submission contributor name/email in edit mode, including final submissions; unpublished identity; classified private user-authored text/location/assets; private or unpublished source snapshots; moderated merge values; base/source/current evidence where private; pending warning titles; and private recovery comparisons/technical details. Use `SentryMask` or the established applicable official boundary at the smallest meaningful content subtree. A published destination does not make an unpublished source or original submission public. Conversely, independently public Event values and normal public editorial/status controls remain visible, and create-mode `Creato come` retains the approved authenticated administrator context rather than being classified as original contributor identity. Do not blanket-mask the screen or all technical/editorial information.

Focused widget assertions cover official masking ancestors and adjacent approved public/account visibility for pending human, imported create, imported update/preview, stale-source, recovery, finalized and create-mode presentations. They prove application wrapping and authorized usability, not native Replay pixels, SDK acquisition or all rendering paths. No new recording or SDK-internal test work is required.

### 6. Preserve lifecycle ownership during composition

Keep `_owner`, activation-bound callbacks, per-execution consumption and current-route effect authority in the existing owner. A wider layout or disclosure must not register a second command listener that replays feedback/navigation. Retain `ObjectKey(viewModel)`, hydration identity, stable form host described above and ordinary typing preservation.

Capture owner/callback references before async boundaries, guard `mounted` before `State.widget`/context access and after awaits, dispose owned controllers/focus nodes, and preserve dialog session/revision revocation. An old map selection, confirmation, recovery choice or hidden terminal cannot mutate or navigate a replacement activation. Keep Save Progress as an observer and Back/dirty-exit arbitration in the current route; no commands from build, resize or disclosure changes.

## Risks / Trade-offs

- Persistent controls consume scarce height with keyboard/large text → wrap, use a bounded secondary action surface and verify the active field remains reachable at small heights.
- Layout switching can remount Forms and lose selection or validation → preserve one form identity and test resizing with unsaved rich text, coordinates and operation state.
- Simplified comparisons may omit important evidence → keep overwrite warnings expanded, retain complete values and use server merge groups only.
- Reordering controls can weaken guards or duplicate effects → reuse callbacks and owner, verify the CTA matrix and existing route/lifecycle tests.
- Read-only styling can accidentally restore interactivity → retain pointer and focus locks and test category/date/map/photo mutation prevention independently of contrast.
- Accessibility exposes a shared photo seam → keep any extension optional and compatible, with a focused public-default regression.
- Usability benefit is inferred, not measured → initial adversarial review evaluates hierarchy and state coverage; later visual acceptance uses representative content and actual rendering.

## Migration Plan

After explicit implementation authorization, change presentation and its targeted tests together. No data migration, backend deployment or canonical-spec sync is part of this work. Rollback is a UI commit revert; it must not discard drafts or rewrite remote state. The existing PR remains Draft for independent implementation review.

## Open Questions

No unresolved product or ownership decision blocks the plan. Exact content/panel width caps and final localized labels can be tuned during implementation within the specified accessibility, eligibility and hierarchy contracts.


### Remediation composition and presentation ownership

Extract identity/metadata, media, decision presentation, verification and semantic merge comparisons into feature-local widgets. The Screen retains both stable Forms, controllers, ViewModel binding, effect authority, command/dialog dispatch, Save Progress and activation-bound navigation. Leaf widgets consume current owner state and callbacks; no new ViewModel, merge engine or eligibility layer is introduced.

Render the original server groups as readable name, category, description, schedule and location values, including explicit unavailable values. Keep exact underlying values in an accessible disclosure. Rich descriptions use the existing codec and read-only rich renderer; when stored plain text differs from its rich projection, show both readably. Public current Event values remain unmasked; moderated/base/source evidence retains its official masks. Keep Current always receives its original group.

Validation summaries are invalidated only by an actual edit to the relevant content field, coordinate section or temporal state, or by owner/activation/hydration retirement. No replacement validation rules or editable copies are introduced. Each ordinary Save revalidates, while captured continuation keeps its existing bypass.

A primary Link decision derives its identity only from a matching ID in the currently authorized candidate list, with municipality and secondary numeric ID when available. Query/target invalidation removes that display identity. Manual or unmatched IDs are explicitly unverified without adding an authorization requirement. Bound the pinned identity text on constrained layouts; complete candidate values remain available in verification.
