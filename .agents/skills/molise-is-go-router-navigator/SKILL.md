---
name: molise-is-go-router-navigator
description: Use when working with GoRouter, Flutter Navigator, Android predictive back, PopScope, LocalHistoryEntry, showGeneralDialog, StatefulShellRoute, AnimatedStatefulShellRoute, NavigationNotification, or interactions between root and branch navigators. Covers legacy and predictive back dispatch, route-owned overlays, pageless dialogs, shell notification races, and reliable back-navigation tests.
---

# GoRouter + Flutter Navigator: Back-Gesture Dispatch & Pop Scope Patterns

## When to Use

Use this skill when:
- Implementing or debugging back-gesture handling (`PopScope`, `onPopInvokedWithResult`)
- Supporting Android predictive back (`flutter/backgesture`, framework back ownership)
- Working with `showGeneralDialog` / `showDialog` pushed onto the root navigator from inside a `StatefulShellRoute` branch
- Rendering a fullscreen overlay as a root GoRouter page
- Using `LocalHistoryEntry` for inline content, search, sheets, or local route state
- Working with `NavigationNotification` or `SystemNavigator.setFrameworkHandlesBack`
- Using `AnimatedStatefulShellRoute` or another shell that keeps inactive branch navigators alive
- Using `Navigator.of(context, rootNavigator: true)` for dialogs, modals, or galleries
- Guarding a route against being popped while an overlaid fullscreen widget (gallery, camera, etc.) is open
- Overriding `deactivate()` for lifecycle-based navigator cleanup
- Analysing why the system back gesture pops the wrong navigator

---

## 1. Legacy and Fallback Android Back Dispatch

### The call chain

For an Android back button, pre-predictive back, or predictive-back fallback,
the request reaches `WidgetsBinding.handlePopRoute()` and then
`GoRouterDelegate.popRoute()`. On iOS, a route edge swipe is handled by the
owning `Navigator`/`PageRoute`. These paths behave differently.

**Do not generalize this section to Android predictive back.** On Android API
33+, the system can complete a back gesture without calling
`handlePopRoute()` at all. Predictive back has a separate observer protocol,
described in the next section.

### `GoRouterDelegate.popRoute()` — Android path

```dart
// go_router 17.x — delegate.dart
Future<bool> popRoute() async {
  final Iterable<NavigatorState> states = _findCurrentNavigators();
  for (final state in states) {
    final bool didPop = await state.maybePop();
    if (didPop) return true;   // first navigator that handles it wins, others skipped
  }
  return false;
}
```

**Key:** GoRouter calls `maybePop()` on the navigators returned by
`_findCurrentNavigators()` **in order, stopping at the first that returns
`true`**. This means only one navigator handles each legacy/fallback pop
request.

This single-handler guarantee applies to `GoRouterDelegate.popRoute()`. It does
not apply to Flutter's predictive-back observer broadcast.

### `_findCurrentNavigators()` — priority and the `isCurrent` guard

```dart
Iterable<NavigatorState> _findCurrentNavigators() {
  final states = <NavigatorState>[];
  states.add(navigatorKey.currentState!);          // root navigator, added first

  RouteMatchBase walker = currentConfiguration.matches.last;
  while (walker is ShellRouteMatch) {
    final NavigatorState potentialCandidate = walker.navigatorKey.currentState!;

    final ModalRoute<dynamic>? modalRoute =
        ModalRoute.of(potentialCandidate.context);
    if (modalRoute == null || !modalRoute.isCurrent) {
      // A pageless route is on top of this shell navigator — stop walking.
      break;
    }
    states.add(potentialCandidate);
    walker = walker.matches.last;
  }
  return states.reversed;   // deepest branch first, root last
}
```

**`states.reversed` means:** branch navigators are tried **before** the root navigator.

**The `isCurrent` guard:** only stops branch-navigator collection when a **pageless route** (e.g. `showDialog`) is on top of **that branch navigator's** modal route. A dialog pushed onto the **root navigator** does NOT affect `isCurrent` of the branch navigator's route. The branch navigator is still added to the list.

### Critical implication: root navigator dialogs do NOT protect branch routes

If `showGeneralDialog(useRootNavigator: true)` pushes a dialog onto the root navigator:

- The branch navigator's `ModalRoute.isCurrent` remains `true`.
- GoRouter adds the branch navigator to the list.
- `states.reversed` → branch first.
- `maybePop()` on the branch navigator runs first.
- If the branch route is poppable, it gets popped — the dialog is bypassed entirely.

**This is the root cause of the "back press pops the screen instead of the dialog" bug.**

---

## 2. Android Predictive Back Is a Separate Protocol

Flutter 3.41 handles Android predictive back through the
`flutter/backgesture` platform channel:

1. `startBackGesture` is broadcast to every registered
   `WidgetsBindingObserver`.
2. Every observer returning `true` is retained for that gesture.
3. `updateBackGestureProgress` is sent to all retained observers.
4. `commitBackGesture` or `cancelBackGesture` is sent to all retained
   observers.

This differs critically from `GoRouterDelegate.popRoute()`: there is no
"first handler wins" rule. Nested root and branch navigators can each have an
enabled predictive-back observer, and every retained observer can commit.

Material's `_PredictiveBackGestureDetector` is enabled only when its route is
current and `PageRoute.popGestureEnabled` is true. `popGestureEnabled` is false
when, among other conditions:

- the route is first in its navigator;
- the route has local history (`willHandlePopInternally`);
- a `PopScope(canPop: false)` makes the route non-poppable;
- a Material page is a `fullscreenDialog`.

Also note that GoRouter's `CustomTransitionPage` creates a custom `PageRoute`
whose `buildTransitions` directly invokes `transitionsBuilder`. It does not
automatically use Material's `PageTransitionsTheme`, so do not assume it owns
Android's predictive transition observer.

### Why nested navigators can pop the wrong layer

Suppose a custom root gallery page sits above a poppable Post route in a shell
branch:

- the custom root page may have no predictive observer;
- the branch Post route remains `isCurrent` within its own navigator;
- the branch predictive observer accepts the gesture;
- committing the gesture pops the branch route;
- GoRouter's configuration update can then remove the gallery too.

This produces a gallery-and-Post double close even though a
`handlePopRoute()` test passes.

### Branch guard for a root overlay

While a root overlay is active, make the source branch route non-poppable and
redirect fallback pop attempts to the root navigator:

```dart
ValueListenableBuilder<bool>(
  valueListenable: RootOverlayState.isOpen,
  builder: (_, isOpen, child) => PopScope(
    canPop: !isOpen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && isOpen) {
        unawaited(
          Navigator.of(context, rootNavigator: true).maybePop(),
        );
      }
    },
    child: child!,
  ),
  child: const SourceScaffold(),
);
```

Set shared visibility synchronously before awaiting the root route push, and
clear it in `finally`. This closes the same-frame race and also handles route
replacement:

```dart
RootOverlayState.isOpen.value = true;
try {
  await context.pushNamed<void>('gallery', extra: serializableExtra);
} finally {
  RootOverlayState.isOpen.value = false;
}
```

---

## 3. Prefer a Route-Owned Root Overlay

When a fullscreen gallery or viewer is application navigation state, model it
as a top-level GoRouter route on the root navigator instead of a pageless
`showGeneralDialog` route.

```dart
GoRoute(
  parentNavigatorKey: rootNavigatorKey,
  path: '/gallery',
  name: 'gallery',
  pageBuilder: (_, state) => CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: false,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
    child: GalleryScreen(data: GalleryData.tryParse(state.extra)),
  ),
),
```

Benefits over a pageless dialog:

- GoRouter owns replacement, redirects, deep links, and restoration.
- `router.pop()`, root `Navigator.maybePop()`, app-bar back, and drag dismissal
  target one managed route.
- Source widgets do not need `deactivate()` cleanup to prevent orphaned
  dialogs.
- External `extra` data can be parsed safely instead of force-cast.

Use primitive, message-codec-compatible route data for restorable extras.
Route ownership solves lifecycle/replacement ambiguity, but it does **not** by
itself isolate predictive-back observers in nested navigators. Keep the branch
guard from Section 2 when the source branch remains predictively poppable.

---

## 4. `LocalHistoryEntry`, `PopScope`, and Framework Back Ownership

`LocalHistoryEntry` is appropriate for inline route-local state such as a
selected map item, search results, or an expanded sheet. A normal
`Navigator.pop()` calls the route's `didPop()`, consumes the newest local entry,
and leaves the page route in place.

However, in Flutter 3.41 adding or removing local history calls
`changedInternalState()` but does not itself dispatch the
`NavigationNotification` needed to update
`SystemNavigator.setFrameworkHandlesBack`. Android can therefore believe
Flutter cannot handle back and background the app without delivering a pop.

Pair transient local history with a `PopScope`:

```dart
PopScope(
  canPop: !hasTransientState,
  onPopInvokedWithResult: (didPop, _) {
    if (didPop || !hasTransientState) return;

    final entry = historyEntry;
    if (entry != null) {
      entry.remove(); // onRemove resets the transient UI.
    } else {
      resetTransientState();
    }
  },
  child: const MapScaffold(),
);
```

The `PopScope(canPop: false)` has two jobs:

- it makes the route advertise that Flutter handles back;
- when fallback dispatch reaches the branch first, its callback removes the
  local entry rather than the page route.

Always honor `didPop`. Do not unconditionally mutate state after a route has
already popped.

### Animated shell notification race

An animated/stateful shell keeps inactive branch navigators alive. During a
branch switch, multiple navigators can emit `NavigationNotification`s. A late
`canHandlePop: false` from an inactive or transitioning branch can overwrite
the active GeoMap branch's earlier `true` at `WidgetsApp`, especially when
opening GeoMap from another branch with route `extra`.

When this occurs, arbitrate above the entire shell, typically in
`MaterialApp.builder`:

```dart
class AppBackNavigationScope extends StatelessWidget {
  const AppBackNavigationScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        if (!AppBackState.hasTransientBackLayer) return false;

        unawaited(SystemNavigator.setFrameworkHandlesBack(true));
        return true;
      },
      child: child,
    );
  }
}
```

```dart
MaterialApp.router(
  routerConfig: router,
  builder: (_, child) => AppBackNavigationScope(child: child!),
);
```

Important constraints:

- Intercept only while known transient state is active.
- Return `false` otherwise so `WidgetsApp` retains its normal navigation
  handling.
- Keep shared state synchronized on initial route extras, content selection,
  search submission, reset, and disposal.
- Consider whether hidden branch state should continue to own system back; if
  not, include active-branch state in the shared predicate.

---

## 5. Pageless Root Dialogs: Branch Guard and Root Policy

For a legacy pageless root-navigator dialog opened from a shell branch, the
source branch guard is essential. A normal `showDialog`/`showGeneralDialog`
route is already poppable on its owning root navigator, so a second root
`PopScope` is not automatically required. Add one only when the dialog needs a
custom root-pop policy. Prefer the route-owned pattern in Section 3 for
application-level fullscreen viewers.

### `PopScope` on the branch screen (`PostScreen` pattern)

Prevents the branch route from being popped while the dialog is open; redirects to the root navigator instead.

```dart
// Track gallery open state with a ValueNotifier — no full-tree rebuild
final ValueNotifier<bool> _isGalleryOpenNotifier = ValueNotifier(false);

@override
void dispose() {
  _isGalleryOpenNotifier.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<bool>(
    valueListenable: _isGalleryOpenNotifier,
    // Use the child parameter to memoize the Scaffold subtree.
    // Only PopScope rebuilds when the notifier changes.
    builder: (_, isGalleryOpen, child) {
      return PopScope(
        canPop: !isGalleryOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            // Branch nav was blocked (canPop: false); redirect to root nav.
            // maybePop() is a no-op if nothing is on the root navigator.
            unawaited(Navigator.of(context, rootNavigator: true).maybePop());
          }
        },
        child: child!,
      );
    },
    child: Scaffold(/* ... */),
  );
}
```

**Why `ValueNotifier` + `ValueListenableBuilder` instead of `setState`:**
- `setState` on a boolean flag rebuilds the entire widget tree of the `State`.
- A `ValueNotifier` scoped to `ValueListenableBuilder` rebuilds only the `PopScope` wrapper.
- Use the `child` parameter to hoist the `Scaffold` out of the builder closure — it is built once and reused on every notifier change.

**Why fire `onGalleryOpened` before `await`:**

```dart
Future<void> _openGallery(int index) async {
  // Notify before await so canPop:false is set synchronously in the same
  // frame the dialog begins opening. Firing after await would leave a window
  // where the back gesture could still pop the branch route.
  widget.onGalleryOpened?.call();

  final result = await GalleryPreviewModal.show(context: context, ...);

  if (!mounted) return;   // guard after every await

  widget.onGalleryClosed?.call();
}
```

### Optional `PopScope` on the root-navigator dialog overlay

Use a root-level `PopScope` only if the dialog intentionally vetoes the default
pop and then performs a custom dismissal. Do not call `maybePop()` on the same
route while its `PopScope.canPop` is false: that asks the same blocked route to
maybe-pop again and can recurse.

```dart
// GalleryPreviewModalOverlay (StatelessWidget rendered inside showGeneralDialog)
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        // pop() performs the custom dismissal after this scope vetoed the
        // original maybePop(). Do not call maybePop() here.
        Navigator.of(context, rootNavigator: true).pop();
      }
    },
    child: /* overlay content */,
  );
}
```

If no custom veto is needed, omit this `PopScope`; the root dialog route's
normal pop behavior is simpler and safer.

**Why `Navigator.of(context, rootNavigator: true)` from inside the dialog:**
The overlay widget's `context` is inside the root navigator's dialog route.
`rootNavigator: true` resolves to the app-level `NavigatorState`, which owns
the dialog.

### How the branch guard and root policy collaborate

| Gesture path | What happens |
|---|---|
| Android `popRoute()` | Branch nav tried first → `PostScreen.PopScope(canPop:false)` fires → `onPopInvokedWithResult` redirects to root nav → dialog dismissed |
| Root `maybePop()` without a custom root scope | The dialog route pops normally |
| Root `maybePop()` with the optional custom scope | The scope vetoes the attempt, then its callback uses `pop()` once |

This table describes `GoRouterDelegate.popRoute()` fallback behavior. For an
Android predictive gesture, apply the observer and branch-guard rules from
Section 2.

---

## 6. `deactivate()` — Lifecycle and the Orphaned-Dialog Question

### What `deactivate()` is for

`deactivate()` fires when a `State`'s element transitions from active to inactive — both when a route is pushed on top (push-behind, element stays in tree) and when a route is removed (element will be disposed). Critically, `mounted` is still `true` and `context` is still valid.

### Prefer ownership over lifecycle inference

`deactivate()` does not tell you whether the element was removed, moved, or
temporarily covered. Prefer a managed root GoRouter route whenever source
replacement must remove the overlay deterministically.

#### Case A — Dialog remains dismissible on the root navigator

If the root dialog remains independently dismissible after the branch screen
is deactivated, reset branch-local guard state without blindly popping the
root navigator:

```dart
@override
void deactivate() {
  // Reset so canPop is correct if this screen is reactivated.
  // Do NOT blindly maybePop() here; a different root route may now be current.
  _isGalleryOpenNotifier.value = false;
  super.deactivate();
}
```

This avoids accidentally removing an unrelated root route during a
push-behind deactivation. It does not make a pageless dialog declaratively
owned: the dialog can still outlive its source until dismissed. If replacement
must remove it automatically, use the route-owned pattern from Section 3.

#### Case B — Dialog intentionally blocks normal pop

`barrierDismissible: false` disables barrier-tap dismissal; it does not by
itself disable system back. A dialog becomes truly non-dismissible when its
route policy, such as `PopScope(canPop: false)`, blocks normal pop and provides
no independent close path.

If such a pageless dialog can outlive its source after a GoRouter replacement,
it can become stranded above the destination.

In tightly controlled legacy code, `deactivate()` can conditionally call
`pop()` to remove that known root dialog. `maybePop()` would respect the same
blocking policy and may not dismiss it:

```dart
@override
void deactivate() {
  // Dismiss any orphaned dialog on the root navigator when this screen is
  // deactivated. This is safe only when the flag proves the current root route
  // is the owned dialog.
  //
  // Push-behind regression concern: deactivate() also fires when a route is
  // pushed on top (not replaced). This is only safe here because the dialog
  // is a fullscreen overlay that physically blocks all UI on this screen —
  // no tap target can trigger a push while the dialog is visible, so
  // isGalleryOpenNotifier.value is always false during any push-behind
  // deactivation in practice.
  if (_isGalleryOpenNotifier.value) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  super.deactivate();
}
```

**The push-behind caveat:** `deactivate()` fires for push-behind deactivations
too. A boolean indicates intent but does not prove which root route is current.
Use this only when the fullscreen dialog blocks every competing navigation
path and the navigator ownership is unambiguous. Otherwise, route ownership is
the safer solution.

### Summary: which pattern to use

| Dialog type | `deactivate()` pattern |
|---|---|
| Root dialog remains independently dismissible | Reset notifier only; do not blindly pop root |
| Route policy blocks normal pop, no independent dismiss path | Conditional `pop()` only under strict ownership guarantees |
| `barrierDismissible: true` | No `deactivate()` override needed — barrier tap dismisses it |
| Managed root GoRouter page | No source `deactivate()` cleanup; router owns replacement |

### Testing `deactivate()` with a navigation call

When testing `deactivate()` that mutates a navigator, give Flutter a complete
frame between setting the dialog-open state and replacing the widget tree.
Calling `pumpWidget` immediately after a bare `pump()` can trigger
`deactivate()` while the rebuild pipeline is active:

```dart
// WRONG — deactivate fires mid-rebuild
notifier.value = true;
await tester.pump();              // starts a rebuild
await tester.pumpWidget(...);     // triggers deactivate() mid-rebuild → crash

// CORRECT — rebuild completes before deactivate fires
notifier.value = true;
await tester.pumpAndSettle();     // rebuild fully complete
await tester.pumpWidget(...);     // deactivate() fires cleanly
await tester.pumpAndSettle();     // navigation mutation completes
```

---

## 7. `mounted` After `await` — Non-Negotiable Rule

Always check `mounted` after every `await` inside a `State` method before accessing `context`, calling `setState`, or invoking callbacks.

```dart
final result = await someAsyncOperation();

if (!mounted) return;   // widget was disposed while awaiting — bail out

// Safe to use context, setState, or callbacks here
widget.onComplete?.call(result);
```

`deactivate()` alone does not set `mounted` to `false`. Only `dispose()` does. A widget that is deactivated (pushed behind) still has `mounted == true`, so the `!mounted` guard does not fire for push-behind deactivations. This is expected and correct.

---

## 8. `PopScope` Type Parameter

Use the untyped form `PopScope(...)` (which defaults to `Object?`) unless the route genuinely produces a typed result. Avoid `PopScope<dynamic>` — it defeats the type system without intent.

```dart
// Bad — weakens type checking
PopScope<dynamic>(canPop: false, ...)

// Good — untyped, route produces no result
PopScope(canPop: false, ...)

// Good — route produces a typed result
PopScope<bool>(canPop: false, onPopInvokedWithResult: (didPop, bool? result) { ... })
```

---

## 9. `unawaited()` for Fire-and-Forget Navigation Calls

In synchronous callbacks (e.g. `onPopInvokedWithResult`, `deactivate()`), navigation calls return `Future`s that cannot be `await`ed. Use `unawaited()` from `dart:async` to signal intent and satisfy the `unawaited_futures` lint:

```dart
import 'dart:async';

onPopInvokedWithResult: (didPop, _) {
  if (!didPop) {
    unawaited(Navigator.of(context, rootNavigator: true).maybePop());
  }
},
```

Do not suppress the lint with `// ignore:` — use `unawaited()` as the explicit, readable, lint-compliant form.

---

## 10. Testing Back Navigation Correctly

`tester.binding.handlePopRoute()` tests only the legacy/fallback path. A test
that passes with `handlePopRoute()` can still double-pop or background the app
under predictive back.

### Send real predictive-back channel messages

```dart
Future<void> commitPredictiveBack(WidgetTester tester) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('startBackGesture', <String, Object?>{
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      }),
    ),
    (_) {},
  );
  await tester.pump();
  await messenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('commitBackGesture'),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}
```

Send `cancelBackGesture` instead of `commitBackGesture` and assert that route
and transient UI state remain unchanged.

### Assert platform ownership, not only widget state

Mock `SystemChannels.platform`, record every
`SystemNavigator.setFrameworkHandlesBack` call, and assert the **last** value
after branch transitions settle:

```dart
final ownership = <bool>[];
messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
  if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
    ownership.add(call.arguments as bool);
  }
  return null;
});

// Put WidgetsApp in a state where it sends ownership updates.
await messenger.handlePlatformMessage(
  'flutter/lifecycle',
  const StringCodec().encodeMessage(AppLifecycleState.resumed.toString()),
  (_) {},
);

// Open/switch to the transient route and settle shell animations.
expect(ownership.last, isTrue);
```

Seeing one intermediate `true` is insufficient; a later inactive-branch
`false` is the failure mode.

### Use the production topology and entry path

Back-navigation regressions must include:

- the real `StatefulShellRoute` or `AnimatedStatefulShellRoute` implementation;
- all persistent branches, not a one-branch approximation;
- a poppable branch route behind the root overlay;
- the exact cross-branch entry path, such as Post to GeoMap with route `extra`;
- URI and visible-widget assertions after each back layer;
- both commit and cancel predictive gestures;
- a real Android emulator smoke test for platform ownership failures.

For GeoMap-like state, verify both content selected inside an already active
map and content supplied while switching into the map branch. They can produce
different notification ordering.

---

## 11. Common Mistakes Summary

| Mistake | Consequence | Fix |
|---|---|---|
| Treating every Android back as `GoRouterDelegate.popRoute()` | Predictive back can commit a different navigator or never call `handlePopRoute()` | Model predictive back as a separate observer protocol |
| Testing predictive behavior only with `handlePopRoute()` | False confidence while real edge gestures still fail | Send `flutter/backgesture` start/commit/cancel messages |
| Testing a shell with one branch | Misses late notifications from persistent inactive branches | Use the production shell and all branches |
| Asserting that ownership was ever `true` | A later `false` can still let Android background the app | Assert the final `setFrameworkHandlesBack` value after settling |
| Assuming a managed root GoRouter route isolates predictive back | The current branch route can still own a predictive observer | Add a branch `PopScope` driven by shared overlay visibility |
| Using `LocalHistoryEntry` alone for Android back ownership | Local state exists, but Android may not deliver back to Flutter | Pair local history with `PopScope` and verify platform ownership |
| Ignoring shell `NavigationNotification` ordering | A late inactive-branch `false` overwrites the active branch's `true` | Arbitrate above the shell only while known transient state is active |
| Always consuming every `NavigationNotification` | Breaks normal Navigator/WidgetsApp ownership updates | Return `false` when no explicit transient override is active |
| No branch guard while a root dialog/page is open | Back pops the hidden branch route or removes both layers | Use `PopScope(canPop: !isOverlayOpen)` and redirect fallback to root |
| Calling `maybePop()` from a `PopScope(canPop:false)` callback on the same route | Repeats the same blocked pop and can recurse | Use normal route behavior, or `pop()` once for an intentional custom dismissal |
| Blindly popping root from `deactivate()` | Push-behind can remove an unrelated root route | Prefer route ownership; use lifecycle cleanup only with strict ownership guarantees |
| Missing `if (!mounted) return` after `await` | Crash or stale-context access if widget was disposed while awaiting | Add the guard after every `await` in `State` methods |
| `setState` on a boolean gallery-open flag | Rebuilds entire widget tree on every gallery open/close | Use `ValueNotifier<bool>` + `ValueListenableBuilder` scoped to `PopScope` |
| `ValueListenableBuilder` without `child` parameter | Scaffold subtree fully rebuilt on every notifier change | Pass `Scaffold(...)` as `child`, use `child!` inside the builder |
| `PopScope<dynamic>` | Type system weakened for no reason | Use untyped `PopScope(...)` |
| Publishing overlay visibility after `await` | Same-frame race where the branch remains predictively poppable | Publish visibility before pushing and clear it in `finally` |
| In tests: `pump()` + immediate `pumpWidget()` when `deactivate()` calls `maybePop()` | "setState called during rebuild" error | Use `pumpAndSettle()` before `pumpWidget()` and `pumpAndSettle()` after |
