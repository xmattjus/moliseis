# Proposal

## Why

The original change separates detailed local diagnostics from controlled remote reporting, removes severity-implied captures and duplicate owners, and prevents logging failures from changing business outcomes. The November 7 investigation at PR #33 HEAD `03cd3eb6d854ad45ef1335638f61749babe9639b` demonstrates why those boundaries matter, while exposing diagnostic information loss and separate automatic Dart/native privacy boundaries that the original scope did not close.

The [complete anonymized investigation](research/2026-11-07-sentry-sanitization-investigation.md) is historical experimental evidence: 59 passing host cases and one passing iOS simulator NSError probe. It establishes synthetic payload behavior, not production disclosure, server Issue grouping, Android runtime behavior, autonomous native crash privacy or Replay privacy. This revision expands the existing change; it does not implement the expansion or certify merge readiness.

## What Changes

**Already implemented in PR #33:** one `Logger.log` API; centralized typed destination/projection; explicit failure ownership; independent best-effort sinks and safe call-site construction; bounded app exceptions; per-report scope isolation and post-enrichment restoration; print/debugPrint capture disabled; Supabase error-wrapper ownership disabled while breadcrumbs/traces remain; SDK boundary enforcement and focused transport regressions. Preserve this work and its completed tasks.

**Newly planned:**

- Improve privacy-safe error discrimination and source localization where feasible, comparing useful retained fields against the demonstrated same-category diagnostic collapse. Retain original exceptions/stacks locally; do not restore arbitrary messages or raw frames.
- Assess overlapping scope-field clearing and final restoration without losing attachment isolation, approved breadcrumbs, correlation or useful non-sensitive technical metadata.
- Define and verify an independent SDK-owned automatic Dart policy that preserves unexpected-error visibility and safe debugging information without arbitrary private content or duplicate application capture.
- Characterize native Android/iOS capture/configuration/callback boundaries, then apply only necessary platform-specific mitigation. Dart callbacks cannot be assumed to cover native-origin events.
- Characterize Replay coverage on contribution/moderation and related diagnostic views, including private free text, restored drafts, assets and error-triggered recordings; add targeted safeguards where required by the reviewed content classification.
- Verify consent, Supabase spans/breadcrumbs, console isolation, voluntary log sharing and cross-channel/concurrency regressions with final-envelope and native evidence appropriate to each channel.
- Retain curated research and an explicit readiness record, including platform limitations and diagnostic/privacy comparisons.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `application-observability`: retain the original logging migration; add safe diagnostic discrimination, complete envelope isolation, separate automatic Dart/native privacy contracts and explicit local/export boundaries.
- `sentry-consent-lifecycle`: add channel-specific evidence and separation of local history/voluntary sharing from automatic telemetry; preserve persisted-consent, deferred opt-in, bounded shutdown and networking semantics.
- `session-replay-privacy`: extend selective protection to reviewed private/unpublished content and diagnostic displays, while retaining useful public/editorial visibility and explicit native recording acceptance.

## Impact

Future implementation may touch `lib/utils/logging/`, SDK bootstrap/platform configuration, installed native integration boundaries, existing consent orchestration, affected Replay widget boundaries and their existing test/support harnesses. Inspect the installed SDK representations and platform sources before choosing algorithms or callbacks. No new dependency or replacement telemetry infrastructure is selected.

This update touches only this change's OpenSpec artifacts and curated research. Canonical specifications remain unchanged. Existing PR #33 and branch remain the single review surface. Initial planning baseline was main `3246b04c8518aef235eab016f42beca4a4fd7bc6`; the research baseline and the documentation preflight HEAD are `03cd3eb6`, with no intervening local/remote HEAD commits at preflight.

## Goals, tradeoffs and non-goals

The outcome is useful diagnostics with an explicit privacy contract at each active boundary, preserving ownership, truthful outcomes, consent and ordinary networking. Bounded projection loses private detail intentionally; total source-location loss and omitted benign technical context merit measured improvement. More channel-specific tests are justified; rewriting every subsystem is not.

No universal recursive sanitizer, regex blacklist, global generic-crash replacement, blanket telemetry shutdown, global Replay masking without evidence, new logger/service/queue, dependency upgrade, database/backend change, sampling redesign or broad refactor is prescribed. No production exposure or server grouping claim is made. Server grouping research is optional unless grouping equivalence becomes an acceptance claim.

## Delivery boundary

New implementation tasks remain open. Characterization precedes uncertain mechanisms, and verified boundaries remain until alternatives pass their privacy and diagnostic controls. Exactly one documentation commit publishes this revision to PR #33. Merge, deployment, canonical synchronization and archival require later authorization; synchronization/archival remain a separate documentation PR after implementation merge.

## Implementation status — November 7 expansion

The expansion now includes bounded application source locations, a separate
automatic Dart exception policy, targeted private proposal/diagnostic Replay
masks, and maintained transport/concurrency controls. See the design's new
implementation evidence and task state. Native reporting remains unchanged by
explicit owner instruction after the pre-start customization limitation was
established. Mandatory native, actual Replay, production export-overlay and
complete automatic attachment acceptance remain unresolved; this is not a
readiness or merge claim. Canonical specs and archived research remain unchanged.
