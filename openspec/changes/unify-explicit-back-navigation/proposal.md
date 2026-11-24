# Proposal

## Why

The shared Back control can remove a different page when an old callback
is reused. Other Back controls choose their own return or fallback.
The same-frame failures include a removed detail reopening on refresh
after a direct Navigator pop and a malformed Admin page completing a
pushed route's result twice.

## What Changes

- Give ordinary explicit Back one source-aware policy. Return to the
  actual permitted predecessor or request canonical Explore root.
- Distinguish pending, refused, superseded and committed departures
  so a rejected or old request cannot displace a later presentation.
- Use the native themed Material Back control while preserving
  existing backgrounds, spacing and full callback overrides.
- Share one action across the applicable error icons and text actions.
  Preserve Dashboard account and presentation admission and the
  malformed Admin page's existing protected exit decision.
- Preserve shell visibility, system Back, native gestures, redirects,
  restoration and all feature-owned destinations and controls.

## Capabilities

### New Capabilities

- `explicit-back-navigation` defines ordinary explicit Back, presentation
  authority, request lifecycle, native presentation and feature overrides.

### Modified Capabilities

None.

## Impact

The implementation affects the app's Router host, the shared control and
routing action, Settings, error and gallery controls, and the terminal
Dashboard action. It uses existing Flutter and GoRouter APIs and adds no
dependencies. Editor and submission policy, Search, local GeoMap, the picker,
shell roots, Sync, logout and third-party controls retain their established
behavior. The active Admin editor and image presentation plans share a few
UI surfaces and continue to own their respective feature contracts.
