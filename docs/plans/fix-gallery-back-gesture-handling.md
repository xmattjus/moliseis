# Implementation Plan: Fix Gallery Back-Gesture Handling

## Problem Statement

On Android, when the gallery preview modal is open via `SwipeImageGallery` (root navigator), pressing the system back button pops the branch navigator's `PostScreen` route before the dialog can dismiss itself. The added `PopScope<void>` + callback plumbing blocks this, but has four issues:

1. **HIGH:** Missing `mounted` check after `await GalleryPreviewModal.show()` — if `PostScreen` is disposed while the gallery is open, `setState()` fires on a disposed `State`.
2. **HIGH:** `setState` on `_isGalleryOpen` rebuilds the entire `PostScreen` widget tree for a boolean flag change.
3. **MEDIUM:** `PopScope<void>` on `PostScreen` has no `onPopInvokedWithResult` — back gestures are silently consumed if the root navigator dialog doesn't intercept first.
4. **MEDIUM:** The gallery dialog lives on the root navigator while callbacks live on the branch navigator. If GoRouter removes the branch route while the gallery is open, the dialog is orphaned.
5. **LOW:** No tests exercise the `PopScope<void>` behavior, `_isGalleryOpen` lifecycle, or callback wiring.

## Solution

1. Add `if (!mounted) return;` after `await` in `_openGalleryPreview()`.
2. Replace `bool _isGalleryOpen` + `setState` with `ValueNotifier<bool>` + `ValueListenableBuilder` scoped to `PopScope.canPop`.
3. Add `onPopInvokedWithResult` to `PostScreen`'s `PopScope<void>` with `Navigator.maybePop(rootNavigator: true)` as fallback.
4. Override `deactivate()` in `_PostScreenState` to pop the root navigator and dismiss any orphaned gallery dialog.
5. Add widget tests for `PopScope.canPop` default state and `ValueNotifier` wiring.

---

## Changes by File

### 1. `lib/ui/post/widgets/post_screen.dart`

**HIGH #2 — Performance / Rebuild scope:** Replace `bool _isGalleryOpen` + `setState` with `ValueNotifier<bool>` + `ValueListenableBuilder` scoped to `PopScope.canPop`:

```dart
final ValueNotifier<bool> _isGalleryOpenNotifier = ValueNotifier(false);

@override
void dispose() {
  _isGalleryOpenNotifier.dispose();
  _slideshowVisibilityNotifier.dispose();
  _scrollController.dispose();
  super.dispose();
}

void _onGalleryOpened() => _isGalleryOpenNotifier.value = true;
void _onGalleryClosed() => _isGalleryOpenNotifier.value = false;

@override
Widget build(BuildContext context) {
  _currentUri = GoRouterState.of(context).fullPath.toString();

  return ValueListenableBuilder<bool>(
    valueListenable: _isGalleryOpenNotifier,
    builder: (_, isGalleryOpen, __) {
      return PopScope<void>(
        canPop: !isGalleryOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            Navigator.of(context, rootNavigator: true).maybePop();
          }
        },
        child: Scaffold(
          // ...existing Scaffold content unchanged...
        ),
      );
    },
  );
}
```

**MEDIUM #3 — Silent back gesture consumption:** Added `onPopInvokedWithResult` above — attempts `maybePop()` on the root navigator as a fallback. If the gallery dialog is present, this dismisses it; if not, it's a no-op.

**MEDIUM #4 — Orphaned dialog on route removal:** Override `deactivate()`:

```dart
@override
void deactivate() {
  // Dismiss any orphaned gallery dialog on the root navigator when this
  // screen is deactivated (e.g., GoRouter removes the branch route while
  // the gallery is open). The gallery uses barrierDismissible: false and
  // has no PopScope of its own, so without this call the dialog would be
  // permanently orphaned with no user-accessible dismiss path.
  //
  // A push-behind regression (deactivate firing when another route is pushed
  // on top) is not a concern here: the gallery dialog is a fullscreen overlay
  // that physically blocks all PostScreen UI — no tap target can trigger a
  // push while the gallery is visible, so isGalleryOpenNotifier.value is
  // always false when a push-behind deactivation occurs in practice.
  if (isGalleryOpenNotifier.value) {
    unawaited(Navigator.of(context, rootNavigator: true).maybePop());
  }
  super.deactivate();
}
```

`deactivate()` fires while `mounted` is still `true` and `BuildContext` is valid. The gallery dialog lives on the root navigator, so `Navigator.of(context, rootNavigator: true).maybePop()` reaches it.

**Why `maybePop()` in `deactivate()` is correct here (not a UX regression):**

Code reviewers have flagged this pattern as potentially causing a push-behind UX regression (deactivating the gallery when a route is merely pushed on top rather than removed). This concern does not apply here because:

- `SwipeImageGallery` uses `showGeneralDialog(barrierDismissible: false)` and renders a **fullscreen opaque overlay** via the root navigator.
- While the gallery is open, all `PostScreen` UI elements (map button, category button, nearby content) are physically hidden behind the gallery overlay — the user cannot tap them.
- Therefore, no navigation call originating from `PostScreen` can occur while `isGalleryOpenNotifier.value == true`.
- The `if (isGalleryOpenNotifier.value)` guard ensures `maybePop()` is only called when the gallery is actually open, making the push-behind scenario a dead code path in practice.

The pattern **would** be a regression risk if the dialog were not fullscreen, or if the branch screen had UI elements accessible while the dialog was open.

### 2. `lib/ui/post/widgets/components/post_media_slideshow.dart`

**HIGH #1 — Missing `mounted` check:** Add guard after `await` in `_openGalleryPreview()` (line 161):

```diff
    widget.onGalleryOpened?.call();

    final isDismissed = await GalleryPreviewModal.show(
      context: context,
      media: widget.media,
      initialIndex: initialIndex,
    );

    widget.onGalleryClosed?.call();

+   if (!mounted) return;

    if ((isDismissed ?? true) && _isAutoPlayEnabled) {
      _startAutoPlay();
    }
```

Note: `onGalleryClosed` is called **before** the `mounted` check intentionally. The callback only writes to a `ValueNotifier` in the parent — it does not access `BuildContext` and is safe to call even if the child is unmounted. The `!mounted` guard protects only `_startAutoPlay()`, which accesses ticker/animation controller state.

### 3. `test/ui/post/widgets/post_screen_test.dart`

**LOW #6 — Missing tests:** Add four test cases to the existing `PostScreen` group:

1. `PopScope allows back navigation by default` — verifies `canPop` is `true` initially.
2. `canPop changes when gallery open/close state changes` — toggles notifier, checks `canPop` flips.
3. `deactivate handles open gallery without crashing` — sets notifier true, replaces widget tree.
4. `PopScope blocks back navigation when gallery is open` — verifies `canPop` becomes `false` and `onPopInvokedWithResult` is wired.

**Test design note — `deactivate` test:**

The `deactivate` test must use `pumpAndSettle()` (not `pump()`) before replacing the widget tree. The reason: `deactivate()` calls `Navigator...maybePop()`, which is a navigation state mutation. If `pumpWidget()` is called immediately after a bare `pump()`, Flutter triggers `deactivate()` while the rebuild pipeline is still active — causing "setState called during rebuild" in the test environment. This error does not occur in production because no user-initiated navigation can happen while the fullscreen gallery overlay is visible.

```dart
// Correct sequence for the deactivate test:
notifier.value = true;
await tester.pumpAndSettle();     // rebuild fully complete before deactivate fires
await tester.pumpWidget(
  _buildTestApp(const SizedBox.shrink(), favouriteViewModel),
);
await tester.pumpAndSettle();     // maybePop() call from deactivate() completes
```

---

## Execution Order

1. **`post_screen.dart`** — Replace `bool _isGalleryOpen` with `ValueNotifier<bool>`, add `ValueListenableBuilder`, `onPopInvokedWithResult`, and `deactivate()` override (findings #2, #3, #4).
2. **`post_media_slideshow.dart`** — Add `if (!mounted) return;` after `await` (finding #1).
3. **`post_screen_test.dart`** — Add tests for `PopScope.canPop` and `ValueListenableBuilder` presence (finding #6).
4. Run `dart analyze` — expect zero errors.
5. Run `flutter test test/ui/post/widgets/post_screen_test.dart` — expect all green.

---

## Risk Assessment

- **Risk level:** Low
- **Direction:** Defensive fixes on a working feature — all changes are additive or replace existing patterns with safer equivalents.
- **Breaking changes:** None — the `onGalleryOpened`/`onGalleryClosed` callbacks on `PostMediaSlideshow` and `PostSectionSlideshow` remain unchanged. Only the internal state management in `PostScreen` changes, and the constructor/API is unaffected.
- **Key risk:** `deactivate()` fires both on push-behind and on route removal. The `maybePop()` call is safe only because the gallery is a fullscreen overlay blocking all branch-screen interactions. If a future change makes `PostScreen` UI elements accessible while the gallery is open (e.g., a non-fullscreen sheet), `deactivate()` would need to be reworked — likely gated with a flag set only during the specific navigation calls that constitute a genuine removal (`pushReplacementNamed`, `go()`).
- **Rollback:** Single revert commit if anything goes wrong.

## Metrics

- **Lines added:** ~30 (`ValueListenableBuilder` wrapping, `deactivate()` override, `mounted` guard, comments)
- **Lines removed:** ~10 (old `setState` callbacks, old `PopScope` without callback, `_isGalleryOpen` dartdoc)
- **Net:** ~20 lines added
- **Test coverage added:** 4 test cases for back-gesture handling
