# Proposal

## Why

App-owned Back controls disagree about where to go. A saved action can pop
a different route, and bypassing GoRouter can reopen a removed route on
refresh. Malformed Admin submission requests also inherit the editor's
deferred exit hook, which can approve multiple pops of one imperative entry.

## What Changes

- Share a small explicit Back decision for eligible originating presentations.
  Pop their actual predecessor-facing route, request canonical Explore root
  when a standalone source permits fallback, or make no request.
- Use the native Material Back control with localized semantics, existing
  customization and a 48 × 48 logical mobile target where the host allows.
  A supplied callback owns the full action.
- Give malformed Admin IDs a protected diagnostic with predecessor-only
  Back. Keep editor exit, authorization and recovery in their existing owners.
- Qualify Gallery Back against its installed Page and live imperative
  entry while preserving the canonical presentation-owned slideshow pause.

## Capabilities

### New Capabilities

- `explicit-back-navigation` defines source-qualified explicit Back,
  its presentation and the departure rules of companion controls.

### Modified Capabilities

None. The routing, shell, Admin editor, image and empty-view contracts
already cover the behavior that this change must preserve.

## Impact

The plan affects shared Back, Settings, ordinary errors, Gallery, the
Dashboard's terminal departure, and routing for malformed Admin IDs.
Category, Post, Search Results and Login inherit the ordinary policy.
Existing control visibility, feature callbacks, platform Back, native
gestures, and the Gallery presentation lifecycle retain their owners.
