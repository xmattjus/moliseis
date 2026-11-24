# Proposal

## Why

App-owned Back controls disagree about where to go, and saved callbacks can
pop a different page. A direct Navigator pop can reopen a page on refresh.
The malformed Admin error can also complete an imperative result twice
when Back requests overlap.

## What Changes

- Share one source-qualified explicit Back policy. Return to the permitted
  predecessor when present and request canonical Explore root otherwise.
- Render the native Material Back button with localized semantics, existing
  styling options and a 48 × 48 mobile target where the layout permits it.
  A supplied callback owns the entire action.
- Share the ordinary policy between applicable error leading and text
  controls, and reuse the terminal decision after Dashboard's feature checks.
- Give malformed Admin submission identifiers a dedicated Admin error route
  with predecessor-only Back. Keep the editor exit policy on the routes that
  own editor state.

## Capabilities

### New Capabilities

- `explicit-back-navigation` defines standard explicit Back and its
  presentation, plus the behavior of companion and protected controls.

### Modified Capabilities

None.

## Impact

The plan affects shared Back, Settings, Route Error, Gallery, the terminal
Dashboard action and routing for malformed Admin identifiers. The malformed
location redirects to a protected error path. Valid editor locations and the
editor's exit behavior stay intact. The plan uses the existing Router host
and dependencies. Editor and submission decisions, local Search and GeoMap
actions, picker results, shell roots, Sync, logout, third-party controls and
native Back gestures retain their owners. The image presentation change owns
slideshow lifecycle and the Admin redesign owns editor presentation.
