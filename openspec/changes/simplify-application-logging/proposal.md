# Simplify application logging

## Why

Typed application logging must preserve business behavior and useful Sentry diagnostics without forwarding arbitrary local data. The November 7 implementation established bounded application and automatic Dart reporting, safe source discrimination, causal breadcrumb isolation and deterministic concurrency controls. The final owner decision makes Talker a Debug-only developer facility and scopes acceptance to supported SDK integration boundaries.

## What changes

- Retain the implemented typed reporting policy, safe exception/frame projection, automatic Dart policy, envelope isolation, Supabase controls and best-effort sink behavior.
- Instantiate and use Talker only under Flutter's compile-time `kDebugMode`. Profile and Release have no Talker sink, console/history, logging route, observer, viewer or export. Sentry forwarding remains independent of a nullable Talker sink; `Logger.log`, severity semantics and reporting ownership are unchanged.
- Mask the private pending-contribution warning title with the official `SentryMask`, retaining current selective Replay configuration and existing masks. Original moderation dashboard title/city remain masked unless independently proven public.
- Formally revise the three delta specifications to replace obsolete native and recording campaign acceptance with the frozen supported-SDK contract. Preserve truthful historical evidence without treating unexecuted tests as passes.

## Capabilities

### Modified capabilities

- `application-observability`: Debug-only local diagnostics, independent production Sentry forwarding, retained Dart telemetry safeguards and explicit native integration limits.
- `sentry-consent-lifecycle`: unchanged persisted consent, deferred opt-in, bounded observation of public `Sentry.close` and application networking ownership; no custom native shutdown guarantee.
- `session-replay-privacy`: official selective masking, classified private application boundaries and focused widget verification, without claiming actual device recordings.

## Impact and boundaries

Implementation remains in PR #33 on `codex/simplify-application-logging`. No new dependency, logging abstraction, runtime diagnostics toggle, application log-file writer, native SDK customization, sampling change or business-flow change is authorized. Accepted SDK limitations are recorded once in [design.md](design.md#accepted-sdk-limitations).

The [November 7 investigation](research/2026-11-07-sentry-sanitization-investigation.md), [native assessment](research/2026-11-07-native-integration-assessment.md) and [implementation evidence](research/2026-11-07-hardening-implementation.md) remain historical evidence; their superseded acceptance obligations do not govern the final freeze.

Final applicable tests, non-Debug build validation where supported, strict OpenSpec validation, full-diff review and CI precede the single final CodeRabbit full-review request. Merge, canonical specification synchronization, archival, a separate post-merge documentation PR and deployment remain outside this implementation; task 5.3 stays open.
