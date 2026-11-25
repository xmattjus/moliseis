part of 'gallery_preview_screen.dart';

/// Observes one slideshow request through opening and actual Gallery removal.
final class GalleryPresentation {
  /// Creates one reservation with a callback for its terminal lifecycle event.
  GalleryPresentation(VoidCallback onEnded) : _onEnded = onEnded;

  VoidCallback? _onEnded;
  VoidCallback? _stopWatchingOpening;
  final _routes = <TransitionRoute<dynamic>>{};

  void _watchOpening(GoRouter router, _GalleryOpeningExtra extra) {
    if (_onEnded == null || _routes.isNotEmpty) return;
    final provider = router.routeInformationProvider;
    final delegate = router.routerDelegate;
    final request = provider.value;

    bool isCommitted() => delegate.currentConfiguration.matches.any(
      (match) =>
          match is ImperativeRouteMatch &&
          match.route.name == RouteNames.gallery &&
          identical(match.matches.extra, extra),
    );

    void onInput() {
      // Refresh reprocesses the same input. A different input can supersede an
      // uncommitted push, while a committed Page may still be about to mount.
      if (!identical(provider.value, request) && !isCommitted()) {
        _openingEnded();
      }
    }

    void onCommit() {
      if (!isCommitted()) _openingEnded();
    }

    provider.addListener(onInput);
    delegate.addListener(onCommit);
    _stopWatchingOpening = () {
      provider.removeListener(onInput);
      delegate.removeListener(onCommit);
    };
  }

  void _openingEnded() {
    if (_routes.isEmpty) _end();
  }

  void _followRoute(
    NavigatorState navigator,
    LocalKey pageKey,
    TransitionRoute<dynamic> route,
  ) {
    if (_onEnded == null || !_routes.add(route)) return;
    _stopWatching();

    void followReplacement() {
      if (_onEnded == null || !navigator.mounted) return;
      for (final page in navigator.widget.pages.whereType<_GalleryPage>()) {
        final replacement = page.routeSlot.route;
        if (page.key == pageKey &&
            replacement != null &&
            !identical(route, replacement)) {
          _followRoute(navigator, pageKey, replacement);
          return;
        }
      }
    }

    unawaited(
      route.popped.then((_) {
        if (_onEnded == null) return;
        // An obsolete pop can recreate this Page's Route in the next build.
        // Observe that reconciliation while the outgoing Route may still paint.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => followReplacement(),
        );
      }),
    );
    unawaited(
      route.completed.then((_) {
        if (!_routes.contains(route)) return;
        followReplacement();
        _routes.remove(route);
        if (_routes.isEmpty) _end();
      }),
    );
  }

  void _stopWatching() {
    _stopWatchingOpening?.call();
    _stopWatchingOpening = null;
  }

  void _end() {
    final onEnded = _onEnded;
    detach();
    onEnded?.call();
  }

  /// Revokes callbacks when the slideshow that owns this request is disposed.
  void detach() {
    _onEnded = null;
    _routes.clear();
    _stopWatching();
  }
}

// Serializers see only the existing primitive Gallery payload. The live
// request is needed only to attach the first Route.
final class _GalleryOpeningExtra extends MapView<String, Object?> {
  _GalleryOpeningExtra(super.map, this.presentation);

  final GalleryPresentation presentation;
}

final class _GalleryPage extends MaterialPage<void> {
  _GalleryPage({
    required super.key,
    required super.name,
    required super.arguments,
    required super.restorationId,
    required super.child,
    required this.presentation,
  });

  final GalleryPresentation? presentation;
  final routeSlot = _GalleryRouteSlot();

  @override
  Route<void> createRoute(BuildContext context) {
    final created = super.createRoute(context) as TransitionRoute<void>;
    routeSlot.route = created;
    presentation?._followRoute(Navigator.of(context), key!, created);
    return created;
  }
}

final class _GalleryRouteSlot {
  TransitionRoute<dynamic>? route;
}
