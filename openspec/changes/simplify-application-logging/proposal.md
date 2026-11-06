# Proposal

## Why

Molise Is already has typed application events, Talker diagnostics, and Sentry integration, but the current `AppLogger` mixes event severity with remote exception capture, uses special-case synthetic events for sync/uploads, and can forward arbitrary metadata into breadcrumbs. It also relies on console-frame filtering to prevent Talker output from being recorded by Sentry print integrations. This makes incident diagnosis harder to reason about and future AI-authored instrumentation easy to misuse.

The audited baseline is `main` at `3246b04c8518aef235eab016f42beca4a4fd7bc6` (2026-11-05). The canonical `application-observability` specification already protects truthful sync and Cloudinary outcomes, bounded remote data, owned captures, and streaming traces. The goal is to simplify the existing logger **without weakening those protections**, telemetry consent, Session Replay privacy, or business behavior.

## What Changes

- Preserve the application-facing `Logger.log(LogEvent, ...)` entry point and Talker/Sentry stack. Specify explicit, typed remote intent independent of severity, with `localOnly`, `breadcrumb`, and `report` as the leading minimal design; characterize existing behavior before migrating each event, rather than silently applying a new default to legacy events.
- Define precise policy behavior for attached/missing causes, diagnostic metadata, level filtering, breadcrumbs accompanying reports, and a single report owner per relevant failure path. Preserve useful local throwable/stack evidence and sufficient safe remote diagnostic context; do not presume arbitrary exception messages or stack traces are safe.
- Make application logging best effort end to end: isolate failures inside the logger (including asynchronous Sentry operations), avoid coupling Talker success to remote reporting, and remove fallible **call-site diagnostic argument construction** that could change a business result.
- Disable automatic Sentry print/debugPrint breadcrumbs and remove Talker-console-shape filtering only after behavioral and payload tests demonstrate preservation of necessary explicit breadcrumbs and automatic crash/tracing/Replay behavior. Inspect non-logger Sentry integration channels, including Supabase, HTTP and SDK-owned telemetry, before changing their configuration.
- Extend the existing SDK boundary test, focused Sentry-envelope/privacy tests, and project agent instructions after the application contract is stabilized. Do not introduce a second CI workflow, a replacement logging framework, or speculative synchronization.
- Stage the work behind a **characterization and contract gate**. Tests and small isolated spikes are allowed to resolve the design, but application migration must not begin until the documented gates are closed and the OpenSpec artifacts updated accordingly.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `application-observability`: explicit destination/reporting policy, per-path capture ownership, best-effort invariance, bounded remote payloads, required report context, removal of automatic console breadcrumbs, and enforceable SDK boundaries while preserving existing sync, Cloudinary, and tracing contracts.

## Impact

Flutter only, primarily `lib/utils/logging/`, focused event definitions/call sites, `lib/main.dart` Sentry options, `lib/utils/command_configuration.dart`, associated unit/integration tests, and a concise `AGENTS.md` logging rule. All changes to code and agent guidance are **future implementation tasks**, not part of this planning-only PR.

Existing `sentry-consent-lifecycle` and `session-replay-privacy` remain authoritative and unchanged. Do not alter Supabase SQL/RPC/Edge Functions, Cloudinary persistence or retry semantics, content-submission idempotency, ObjectBox schemas, app networking ownership, Sentry sampling/tracing, or release/deployment configuration.

## Non-goals

No new logging service, three-method replacement API, global deduplication queue, universal sanitizer, speculative await of every breadcrumb, new telemetry or metrics store, arbitrary Unicode text excerpts, Replay redesign, or mass rewrite of every low-value event. Production data exposure and historical Issue grouping are **not** claimed without evidence.

## Planning and delivery boundary

This PR contains OpenSpec artifacts only. It authorizes characterization and design review, **not application code migration, merging, canonical spec synchronization, archival, or deployment**. The implementation owner must revalidate mainline and close the explicit design gate before changing production logging. Use a separate implementation authorization and reviewable PR when that stage begins.
