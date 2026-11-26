# Proposal

## Why

The visible Back control on standalone Login can pop the only route and
trigger a navigation assertion. Ordinary Back can also target the wrong
Navigator when its source is covered or inactive, and a direct Navigator pop
can leave stale route information that reopens the page on refresh.

## What Changes

- Give ordinary Back one source-qualified decision. Pop its own route, request
  canonical Explore root from an eligible standalone page, or do nothing.
- Use the native Material Back control with localized semantics, existing
  customization and a 48 × 48 mobile interaction target where the host permits.
- Keep feature overrides, protected Admin departures, native gestures and the
  existing Gallery presentation lifecycle under their current owners.

## Capabilities

### New Capabilities

- `explicit-back-navigation` defines ordinary Back behavior and shared control
  presentation.

### Modified Capabilities

None.

## Impact

The change covers Settings, Login, ordinary Category, Post, Search Results,
route errors, Gallery, Gallery Unavailable and Dashboard's terminal Back.
Existing Admin routing and admission remain in place.

## Outside this change

The existing protected departure policies remain in force. Ordinary explicit
Back qualifies its source before dispatch. Atomic completion of deferred
exits is tracked in [Harden deferred route exits](../harden-deferred-route-exits/proposal.md).
Admin history after authorization changes is tracked separately in
[Investigate and harden Admin navigation authorization](../harden-admin-navigation-authorization/proposal.md).
