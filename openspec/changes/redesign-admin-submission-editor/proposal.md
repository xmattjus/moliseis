# Proposal

## Why

The Admin editor currently places content, media, reconciliation controls and moderation decisions in one long scroll, with Save at the end and reduced opacity on final-state fields. This structure creates a reasonable risk of missed actions and difficult review; Intervention C improves hierarchy and readability without changing moderation or persistence behavior.

## What Changes

- Lead with content identity and status, followed by the existing shared content form, photos/location, contextual verification, moderation decisions and secondary metadata.
- Replace scroll-end actions with one adaptive persistent action area: compact bottom area or expanded moderation side panel when space permits.
- Prioritize one state-appropriate action and explain blockers while preserving all existing eligibility rules, separate Save and Publish operations, confirmations and Save Progress navigation.
- Present provenance, stale-source warnings and existing merge groups clearly; disclose secondary details without concealing overwrite conflicts or acknowledgement consequences.
- Present accepted/rejected content at normal contrast with explicit read-only status and publication linkage.
- Reuse the existing location editor/map picker and photo components, retaining their validation, staging, progress and recovery information.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `admin-submission-editor`: Add observable workspace hierarchy, adaptive action presentation, contextual verification and readable final-state requirements. Existing persistence, navigation and moderation requirements remain unchanged.

## Impact

Future implementation is limited primarily to `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart`, cohesive feature-local presentation sections, and targeted widget/routing regressions. It reuses `ContentSubmissionFields`, `AdminSubmissionLocationEditor`, `AdminSubmissionRecoveryPanel`, shared photo widgets and existing ViewModel commands. A small compatible presentation extension to a shared widget is allowed only where justified by accessibility or read-only presentation, with the public editor's defaults preserved.

Confirmed behavior is established by current source and tests, not usability measurements; action discoverability and cognitive-load improvements are design hypotheses to review. This PR contains planning artifacts only and does not authorize implementation.

Excluded: Dashboard Back/refresh/recovery changes (Intervention A), new map-picker functionality (Intervention B), database/Edge Function/RPC changes, backend moderation, domain semantics, draft protocols, authentication/authorization, navigation architecture, global theming, unrelated screens, packages and state-management changes. No auto-save or composite Save-and-Publish operation is proposed.
