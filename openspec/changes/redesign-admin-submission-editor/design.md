# Design

## Context

See `proposal.md` for motivation and scope. This is an Intervention C planning change; implementation requires separate authorization.

### Verified implementation and ownership

- `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart` composes a `CustomScrollView`: recovery controls, shared content fields, location, photos, contributor identity, status/source/candidates/merge groups, moderation and finally Save. The app bar names the editor operation rather than the content. Source values and merge maps are rendered as text; publication/rejection sit alongside contextual linking and preview controls. Final-state form/location wrappers use opacity 0.55 and prevent pointer/focus interaction.
- `ContentSubmissionFields` owns shared field presentation and validation, receives controlled event-date state and `hydrationRevision`, and preserves private text masking. It must remain the single content form; category, municipality, name, rich description, event discriminator, all-day mode and dates remain available with existing semantics.
- `AdminSubmissionLocationEditor` owns its local Map/Coordinates display mode and coordinate controllers. Its coordinate Form stays mounted offstage for Save validation. It already calls `showGeoMapLocationPicker()`, captures the activation-bound callback before awaiting, ignores cancellation and identical-point confirmation, and preserves raw draft values. No Intervention B implementation is needed.
- Shared `ContentSubmissionAddAssetButton` and `ContentSubmissionAssetListItem` render photo controls. The Screen/owner provides staged files, confirmed associations, capacity, progress, errors and picker cancellation. The current remove overlay has a 24 logical-pixel constrained target: accessibility needs a compatible presentation adjustment, not replacement of the media workflow.
- `AdminSubmissionRecoveryPanel` displays coherent local/remote field differences and delegates choices; it does not persist. It already adapts comparison columns to available width.
- `AdminSubmissionEditorViewModel` owns current fields, exact authority, command reservations, source acknowledgement, candidate/target selection, preview invalidation and admission. `isDirty` includes unconfirmed fields, staged work and unresolved write intent; it differs from local exit dirtiness. `canRequest*` alone is not a replacement for the Screen's dirty/category checks or request-time validation.
- `AdminSubmissionEditorRoute`, router exit policy and application-owned draft/save session own route restoration and exit decisions. `_save` validates both mounted forms and temporal state, admits Save synchronously and then pushes Save Progress. Save keeps the editor open; qualifying moderation terminals close only their owning editor. Existing publish/reject dialogs capture revisions and revoke covered/obsolete dialog authority.

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

Use secondary disclosure for incidental metadata and unchanged comparison details, not warnings or required choices. Moving private text requires retaining or adding the corresponding `SentryMask`, including the new identity summary. Do not infer that imported content or a technical disclosure is safe for telemetry.

### 2. One action composition adapts to actual space

Compact/medium structure: editor app bar and identity; scrollable content/verification/details; a bottom decision surface outside that scroll. Include primary action and blocker/status copy, with secondary decisions in a labeled expandable action surface when they cannot fit. An expanded secondary surface scrolls within the available viewport and exposes all applicable actions without requiring form scrolling. It has one instance of each decision control. Target/search inputs remain in verification; Keep Current remains next to its group. No FAB or duplicate scroll-end Save.

Expanded structure: constrained content column beside a persistent, bounded moderation panel with status, blocker, primary and secondary decisions. The panel scrolls internally if its content exceeds available height. Verification values stay in the content column rather than stretching the side panel into a second form.

Use the existing Material window-size/spacing conventions (`windowSizeClass`, with compact <600, medium <840, expanded <1200) as context, and local layout constraints for the actual decision. Start side-panel eligibility at expanded width only when a readable content column, gap and action panel fit; fall back if scaled labels or host constraints cannot fit. Do not apply an unrelated `ResponsiveScaffold` map/bottom-sheet composition wholesale. Exact width caps and spacing are presentation tuning, not new global breakpoints.

Respect bottom SafeArea, keyboard insets and existing navigation surfaces. The compact decision surface stays reachable above the keyboard; expanded secondary actions must not consume the whole editor height. Wrap/stack labels and let content scroll so the active field and its error can be brought into view. Reparenting must preserve shared field/controller identity, form validation, current text and selection; resizing is never a hydration event. Do not mount two copies of a form or action surface to implement responsiveness.

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

Save/Publish remain separate. Forward existing callbacks, activation tokens, request guards, confirmation dialogs, current revision checks and error mapping. Link/Preview/Apply are not newly given Publish/Reject confirmation semantics. The matrix describes priority, not backend readiness: coordinate, city, temporal, asset and category checks remain at their current validation boundaries, including actionable backend failures.

### 4. Reconciliation is contextual, complete and server-described

Use existing `AdminEventMergePreview.groups` and `apply`, `overwrite`, `providerChanged`, `moderatorChanged` flags. Show overwrite groups first, then other consequential groups, then unchanged groups; retain original group objects for Keep Current. Use clear labels for proposed moderated/current Event values, and base/source details. Overwrite warnings and proposed/current values are expanded by default and cannot be hidden behind a disclosure. Long text wraps; a full-value surface remains reachable, including rich-description structure where needed to explain formatting differences. Do not replace opaque values with a lossy one-line summary.

Keep stale-source warnings and current-source acknowledgement visible with their actual consequences. Distinguish acknowledgement from Save and from Apply selection; retain the existing complete-revision rejection explanation and ignore-future-source checkbox in Reject confirmation. Preserve advisory pending warnings, candidate search errors, selected Event identity and manual target entry. No client-side merge computation, automatic target choice or provider normalization is added.

Recovery comparison is separate from source reconciliation: accepting remote or keeping local changes the existing baselines only as already defined. Keep checkpoint-not-durable copy, staged association uncertainty and invalid progress notices visible. No disclosure or layout change triggers persistence or restores revoked evidence.

### 5. Minimal boundaries and shared accessibility

Keep the Screen as the composition/effect owner. Extract at most cohesive feature-local identity/details, verification and decision sections when needed for readability; these receive values and bound callbacks, not repositories or new command owners. Do not mandate a file per subsection, a CTA engine, a new state model or a shared workspace abstraction. No ViewModel split is needed.

Reuse `ContentSubmissionFields` unchanged by default. Remove outer global opacity, retain focus/pointer locks, add explicit read-only status, and prevent category/date/map interactions in final states. If a shared field's native disabled visuals defeat normal contrast, use a narrowly justified optional presentation input with editable defaults, not a parallel Admin form. The existing `AdminSubmissionLocationEditor` and map helper remain intact; no routing abstraction is added.

The photo removal overlay's current 24-pixel target justifies a small optional presentation sizing input on `ContentSubmissionAssetListItem` if the existing caller cannot enlarge the hit area safely. Admin requests at least 48 pixels; public callers retain defaults and deletion/upload logic. Keep the visible icon appropriately sized and adjust photo spacing to avoid overlapping hit areas. Verify the compatible shared seam without expanding into a public editor redesign.

Use theme `ColorScheme` roles and existing shapes/spacing. Fraunces remains display/headline/titleLarge, Lexend the other roles per `app-typography`; use semantic styles rather than per-widget font declarations. Avoid decorative cards around every field, new colors, animation dependencies and fixed-height action rows. Provide headings, meaningful labels, expanded-state semantics, keyboard activation, logical reading/focus traversal and non-color status/error cues. Verify minimum targets, light/dark contrast and large text with the actual rendered controls.

### 6. Preserve lifecycle ownership during composition

Keep `_owner`, activation-bound callbacks, per-execution consumption and current-route effect authority in the existing owner. A wider layout or disclosure must not register a second command listener that replays feedback/navigation. Retain `ObjectKey(viewModel)`, hydration identity, always-mounted location Form and ordinary typing preservation.

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

After explicit implementation authorization, change presentation and its targeted tests together. No data migration, backend deployment or canonical-spec sync is part of this work. Rollback is a UI commit revert; it must not discard drafts or rewrite remote state. This planning PR remains Draft for architecture, scope and regression-protection review.

## Open Questions

No unresolved product or ownership decision blocks the plan. Exact content/panel width caps and final localized labels can be tuned during implementation within the specified accessibility, eligibility and hierarchy contracts.
