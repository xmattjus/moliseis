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
- Keep the malformed Admin error on its protected predecessor-only path.
  Its concurrent page pops require a separate departure decision before
  implementation can start.

## Capabilities

### New Capabilities

- `explicit-back-navigation` defines standard explicit Back and its
  presentation, plus the behavior of companion and protected controls.

### Modified Capabilities

None.

## Impact

The ordinary plan affects shared Back, Settings, ordinary Route Error,
Gallery and the terminal Dashboard action. It uses the existing Router host
and dependencies. Editor and submission decisions, local Search and GeoMap
actions, picker results, shell roots, Sync, logout, third-party controls and
native Back gestures retain their owners. The image presentation change owns
slideshow lifecycle and the Admin redesign owns editor presentation.
