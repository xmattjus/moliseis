# Proposal

## Why

Three terminal reporting paths can turn an expected, handled connection failure into a Sentry exception event. Their producers already preserve enough type information to distinguish these failures from a server rejection or an unreadable acknowledgement. TASK-46 corrects the capture decision at the existing owner.

## What Changes

- Keep the terminal diagnostic and its approved breadcrumb for Cloudinary uploads, public submissions and Admin staged asset association. Suppress application exception capture when the attached cause is recognized as connectivity.
- Keep eligible server, contract and unexpected failures visible, including opaque fetch wrappers. Verify the distinction through actual producers and a recording Sentry transport.
- Assess the centralized reporting policy against local refactoring, type-driven policies and the installed Sentry APIs. Retain the central allowlist.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `application-observability` gains an explicit capture rule for handled connectivity failures in the three upload and association paths.

## Impact

The implementation affects the application reporting decision and focused Flutter host tests. Business results, retry and cancellation, receipt persistence and replay, authorization, backend APIs, consent lifecycle, sampling and SDK-owned reporting keep their existing contracts. New dependencies, connectivity probes, transport decorators, a general logging migration and PR #44 are outside scope.
