import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';

/// Whether the location, including diagnostics, needs continuous Admin access.
bool isProtectedAdminLocation(String path) {
  final location = path.toLowerCase();
  return location != RoutePaths.adminLoginLocation &&
      (location == RoutePaths.admin ||
          location.startsWith('${RoutePaths.admin}/'));
}

typedef _PublicCoverRestore = ({
  RouteMatchList source,
  RouteMatchList replacement,
  ({Uri uri, Object? extra})? pendingGo,
});

/// Keeps Admin history reconciliation inside GoRouter's match configuration.
final class AdminRouteHistoryRouter extends GoRouter {
  /// Retains normal GoRouter navigation and fences Admin history at its inputs.
  AdminRouteHistoryRouter({
    required RoutingConfig routing,
    required AdminAuthViewModel auth,
    required VoidCallback onAuthorityRetired,
    required ValueGetter<ValueKey<String>?> pendingContentSubmissionExit,
    required GlobalKey<NavigatorState> navigatorKey,
    required Listenable refreshListenable,
    required List<NavigatorObserver> observers,
    required GoRouterPageBuilder errorPageBuilder,
  }) : _auth = auth,
       _onAuthorityRetired = onAuthorityRetired,
       _pendingContentSubmissionExit = pendingContentSubmissionExit,
       _authority = auth.authority,
       super.routingConfig(
         routingConfig: ValueNotifier(routing),
         navigatorKey: navigatorKey,
         initialLocation: RoutePaths.home,
         restorationScopeId: 'router',
         refreshListenable: refreshListenable,
         observers: observers,
         errorPageBuilder: errorPageBuilder,
       ) {
    _auth.addListener(_authChanged);
    routerDelegate.addListener(_configurationCommitted);
  }

  final AdminAuthViewModel _auth;
  final VoidCallback _onAuthorityRetired;
  final ValueGetter<ValueKey<String>?> _pendingContentSubmissionExit;
  _PublicCoverRestore? _pendingPublicRestore;
  _PublicCoverRestore? _applyingPublicRestore;
  AdminAuthority? _authority;
  RouteMatchList? _retiring;
  bool _interrupted = false;
  int _dashboardReplacement = 0;
  bool _validatingRestoredHistory = false;
  AdminAuthority? _configurationAuthority;
  final _parsed = Expando<({AdminAuthority? authority})>();

  late final _parser = _AdminHistoryParser(super.routeInformationParser, this);

  @override
  GoRouteInformationParser get routeInformationParser => _parser;

  /// Lets the existing exit policy release an obsolete configuration promptly.
  bool get removingRetiredAdmin =>
      identical(_retiring, routerDelegate.currentConfiguration);

  /// Whether this exit callback refers to the original retained form Page.
  ///
  /// GoRouter rechecks the old suffix even when a Page remains in that suffix.
  bool retainsContentSubmission(GoRouterState state) {
    final restore = _applyingPublicRestore;
    final current = routerDelegate.currentConfiguration;
    if (restore == null ||
        !removingRetiredAdmin ||
        !identical(restore.source, current)) {
      return false;
    }
    return current.matches.any(
      (match) =>
          match is ImperativeRouteMatch &&
          match.route.name == RouteNames.contentSubmission &&
          match.pageKey == state.pageKey &&
          restore.replacement.matches.any(
            (retained) => identical(retained, match),
          ),
    );
  }

  /// An untrusted saved request cannot begin an editor exit lookup.
  bool get validatingRestoredHistory => _validatingRestoredHistory;

  /// Authority of the actual committed configuration, including before build.
  AdminAuthority? get admittedAuthority =>
      !removingRetiredAdmin &&
          identical(_configurationAuthority, _auth.authority)
      ? _configurationAuthority
      : null;

  void _configurationCommitted() {
    final current = routerDelegate.currentConfiguration;
    final parsed = _parsed[current];
    // Physical Back can remove matches without parsing another request.
    if (parsed != null) _configurationAuthority = parsed.authority;
    if (!removingRetiredAdmin) _retiring = null;
    final restore = _applyingPublicRestore;
    final pendingGo = restore?.pendingGo;
    _pendingPublicRestore = null;
    if (pendingGo != null && identical(restore?.replacement, current)) {
      final request = routeInformationProvider.value;
      scheduleMicrotask(() {
        if (identical(current, routerDelegate.currentConfiguration) &&
            identical(request, routeInformationProvider.value)) {
          go(pendingGo.uri.toString(), extra: pendingGo.extra);
        }
      });
    }
    if (_containsAdmin(current) &&
        admittedAuthority == null &&
        !removingRetiredAdmin) {
      // A delegate exit may already have been accepted before the replacement
      // request invalidated its parser transaction. Qualify the late commit
      // before any builder can use it, and remove it through the router again.
      _retiring = current;
      scheduleMicrotask(() {
        if (identical(_retiring, current)) _removeRetiredHistory(current);
      });
    }
  }

  RouteMatchList _recordAdmission(RouteMatchList matches) {
    _parsed[matches] ??= (authority: _auth.authority);
    return matches;
  }

  String get _adminLanding =>
      _auth.isAdmin ? RoutePaths.admin : RoutePaths.adminLoginLocation;

  void _authChanged() {
    final previous = _authority;
    if (identical(previous, _auth.authority)) return;
    _authority = _auth.authority;
    final current = routerDelegate.currentConfiguration;
    if (previous != null) {
      _interrupted = true;
      _onAuthorityRetired();
    }
    if (current.isEmpty && !current.isError) {
      // Supersede any Admin request whose parser started before observation.
      if (isProtectedAdminLocation(routeInformationProvider.value.uri.path)) {
        go(_adminLanding);
      }
      return;
    }
    if (_containsAdmin(current)) {
      _removeRetiredHistory(current);
      return;
    }
    final top = _topUri(current);
    if (top.path == RoutePaths.adminLoginLocation && _auth.isAdmin) {
      _navigateFrom(current.remove(current.last), Uri.parse(RoutePaths.admin));
      return;
    }
    final target = _withoutAdminSyncReturn(top);
    if (target != top) {
      _navigateFrom(current.remove(current.last), target);
      return;
    }
    // A push or onEnter can still be pending above entirely public history.
    // Reissue the exact safe configuration to revoke that captured request.
    if (isProtectedAdminLocation(routeInformationProvider.value.uri.path)) {
      restore(current);
    }
  }

  _PublicCoverRestore? _requestedPublicRestore(
    RouteMatchList current,
    Object? request,
  ) {
    final restore = _pendingPublicRestore;
    return restore != null &&
            identical(restore.source, current) &&
            request is RouteInformationState &&
            request.type == NavigatingType.restore &&
            identical(request.baseRouteMatchList, restore.replacement)
        ? restore
        : null;
  }

  void _removeRetiredHistory(RouteMatchList current) {
    if (_requestedPublicRestore(
          current,
          routeInformationProvider.value.state,
        ) !=
        null) {
      return;
    }
    _pendingPublicRestore = null;
    final top = _topUri(current);
    final obsolete = _protectedMatch(current.matches);
    _retiring = current;
    final prefix = obsolete == null
        ? RouteMatchList.empty
        : current.remove(obsolete);
    final cover = current.lastOrNull;
    final publicForms = current.matches
        .skip(prefix.matches.length)
        .whereType<ImperativeRouteMatch>()
        .where((match) => match.route.name == RouteNames.contentSubmission);
    final pendingPublic = _pendingPublicGo(current);
    final target = _withoutAdminSyncReturn(
      pendingPublic?.uri ??
          (isProtectedAdminLocation(top.path) ? Uri.parse(_adminLanding) : top),
    );
    if ((target == top || publicForms.isNotEmpty) &&
        cover is ImperativeRouteMatch &&
        !isProtectedAdminLocation(top.path) &&
        top.path != RoutePaths.sync &&
        (prefix.isNotEmpty || publicForms.isNotEmpty)) {
      var replacement = prefix.isEmpty
          ? configuration.findMatch(Uri.parse(RoutePaths.home))
          : prefix;
      for (final form in publicForms) {
        if (!identical(form, cover)) replacement = replacement.push(form);
      }
      replacement = replacement.push(cover);
      if (publicForms.isNotEmpty) {
        final pendingExit = _pendingContentSubmissionExit();
        // An already-delegated public exit can finish on its existing decision.
        // Replay a pending request only if its own exit has not started yet.
        final pendingGo =
            pendingPublic?.uri == top ||
                publicForms.any((match) => match.pageKey == pendingExit)
            ? null
            : pendingPublic;
        _pendingPublicRestore = (
          source: current,
          replacement: replacement,
          pendingGo: pendingGo,
        );
      }
      restore(replacement);
      return;
    }
    _navigateFrom(
      prefix,
      target,
      extra: target.path == RoutePaths.admin
          ? ++_dashboardReplacement
          : pendingPublic != null
          ? pendingPublic.extra
          : target == top
          ? _topExtra(current)
          : null,
    );
  }

  ({Uri uri, Object? extra})? _pendingPublicGo(RouteMatchList current) {
    final request = routeInformationProvider.value;
    final state = request.state;
    if (state is! RouteInformationState ||
        state.type != NavigatingType.go ||
        (request.uri == current.uri &&
            current.lastOrNull is! ImperativeRouteMatch) ||
        isProtectedAdminLocation(request.uri.path) ||
        configuration.findMatch(request.uri).isError) {
      return null;
    }
    return (uri: request.uri, extra: state.extra);
  }

  void _navigateFrom(RouteMatchList prefix, Uri target, {Object? extra}) {
    if (prefix.isEmpty) {
      go(target.toString(), extra: extra);
    } else if (_topUri(prefix) == target) {
      restore(prefix);
    } else {
      // Use a qualified base in the same request. Using GoRouter.push would
      // capture the old delegate base until replacement completed.
      unawaited(
        routeInformationProvider.push<void>(
          target.toString(),
          base: prefix,
          extra: extra,
        ),
      );
    }
  }

  /// Normal Admin-return URI carries no private target across discontinuity.
  Uri _withoutAdminSyncReturn(Uri uri) {
    final from = Uri.tryParse(uri.queryParameters['from'] ?? '');
    if (uri.path != RoutePaths.sync ||
        from == null ||
        from.hasAuthority ||
        from.hasScheme ||
        !isProtectedAdminLocation(from.path) ||
        from.toString() == RoutePaths.admin) {
      return uri;
    }
    return Uri.parse(RoutePaths.syncFor(Uri.parse(RoutePaths.admin)));
  }

  static Uri _topUri(RouteMatchList matches) {
    final top = matches.lastOrNull;
    return top is ImperativeRouteMatch ? top.matches.uri : matches.uri;
  }

  static Object? _topExtra(RouteMatchList matches) {
    final top = matches.lastOrNull;
    return top is ImperativeRouteMatch ? top.matches.extra : matches.extra;
  }

  static RouteMatchBase? _protectedMatch(List<RouteMatchBase> matches) {
    for (final match in matches) {
      if (isProtectedAdminLocation(match.matchedLocation) ||
          match is ImperativeRouteMatch &&
              isProtectedAdminLocation(match.matches.uri.path)) {
        return match;
      }
      if (match is ShellRouteMatch) {
        final protected = _protectedMatch(match.matches);
        if (protected != null) return protected;
      }
    }
    return null;
  }

  bool _containsAdmin(RouteMatchList matches) =>
      isProtectedAdminLocation(matches.uri.path) ||
      _protectedMatch(matches.matches) != null;

  RouteMatchList _freshRestoration(
    RouteMatchList matches, {
    required bool canResume,
  }) {
    final top = _topUri(matches);
    final safeSync = _withoutAdminSyncReturn(top);
    if (!_containsAdmin(matches)) {
      return safeSync == top ? matches : configuration.findMatch(safeSync);
    }
    final obsolete = _protectedMatch(matches.matches);
    final prefix = obsolete == null
        ? RouteMatchList.empty
        : matches.remove(obsolete);
    if (isProtectedAdminLocation(top.path)) {
      // A cold, declarative editor can validate its own account-qualified hint.
      // Never restore an old imperative editor stack or outstanding Progress.
      if (canResume &&
          _auth.isAdmin &&
          matches.lastOrNull is! ImperativeRouteMatch &&
          !top.path.endsWith('/save-progress')) {
        return configuration.findMatch(top);
      }
      final current = routerDelegate.currentConfiguration;
      if (_topUri(current).path == _adminLanding && !removingRetiredAdmin) {
        return current;
      }
      return prefix.isNotEmpty
          ? prefix
          : configuration.findMatch(Uri.parse(_adminLanding));
    }
    if (prefix.isEmpty) return configuration.findMatch(safeSync);
    if (_topUri(prefix) == safeSync) return prefix;
    final cover = matches.lastOrNull;
    return cover is ImperativeRouteMatch && safeSync == top
        ? prefix.push(cover)
        : configuration.findMatch(safeSync);
  }

  @override
  void dispose() {
    _auth.removeListener(_authChanged);
    routerDelegate.removeListener(_configurationCommitted);
    _retiring = null;
    _pendingPublicRestore = null;
    super.dispose();
  }
}

/// Qualifies decoded restoration and in-flight parses before the delegate can
/// install their match lists. Ordinary route matching stays with GoRouter.
final class _AdminHistoryParser extends GoRouteInformationParser {
  _AdminHistoryParser(this._delegate, this._router)
    : super(
        configuration: _delegate.configuration,
        router: _router,
        onParserException: _delegate.onParserException,
      );

  final GoRouteInformationParser _delegate;
  final AdminRouteHistoryRouter _router;
  final _reported = Expando<AdminAuthority>('reported Admin authority');

  @override
  Future<RouteMatchList> parseRouteInformationWithDependencies(
    RouteInformation information,
    BuildContext context,
  ) {
    final authority = _router._auth.authority;
    final current = _router.routerDelegate.currentConfiguration;
    final request = information.state;
    final base = request is RouteInformationState
        ? request.baseRouteMatchList
        : null;
    final needsValidation = request is! RouteInformationState
        ? request != null &&
              (authority == null ||
                  !identical(_reported[information], authority))
        : base != null &&
              _router._containsAdmin(base) &&
              (!identical(base, current) || _router.removingRetiredAdmin);
    final safeSync = needsValidation
        ? _router._withoutAdminSyncReturn(information.uri)
        : information.uri;
    final previousValidation = _router._validatingRestoredHistory;
    _router._validatingRestoredHistory = needsValidation;
    late final Future<RouteMatchList> parsed;
    try {
      parsed = _delegate.parseRouteInformationWithDependencies(
        safeSync == information.uri
            ? information
            : RouteInformation(uri: safeSync),
        context,
      );
    } finally {
      _router._validatingRestoredHistory = previousValidation;
    }
    final admitted = parsed.then((matches) {
      if (!needsValidation && identical(authority, _router._auth.authority)) {
        return _router._recordAdmission(matches);
      }
      final continuous =
          authority != null &&
          identical(authority, _router._auth.authority) &&
          !_router.removingRetiredAdmin;
      if (continuous && current == matches) return current;
      return _router._recordAdmission(
        _router._freshRestoration(
          matches,
          canResume: continuous && !_router._interrupted && current.isEmpty,
        ),
      );
    });
    final restore = _router._requestedPublicRestore(current, request);
    if (restore == null) return admitted;

    // Deliver only this parsed replacement with a synchronous exit-policy
    // scope. A refresh can reparse the same request in a separate callback.
    final scoped = Completer<RouteMatchList>.sync();
    unawaited(
      Future<RouteMatchList>.value(admitted).then<void>((matches) {
        final active =
            identical(matches, restore.replacement) &&
            identical(information, _router.routeInformationProvider.value) &&
            identical(restore, _router._pendingPublicRestore);
        if (!active) {
          if (identical(information, _router.routeInformationProvider.value) &&
              identical(restore, _router._pendingPublicRestore)) {
            _router._pendingPublicRestore = null;
          }
          scoped.complete(matches);
          return;
        }
        _router._applyingPublicRestore = restore;
        try {
          scoped.complete(matches);
        } finally {
          _router._applyingPublicRestore = null;
        }
      }, onError: scoped.completeError),
    );
    return scoped.future;
  }

  @override
  RouteInformation? restoreRouteInformation(RouteMatchList configuration) {
    final result = _delegate.restoreRouteInformation(configuration);
    final authority = _router._auth.authority;
    if (result != null &&
        authority != null &&
        identical(configuration, _router.routerDelegate.currentConfiguration) &&
        !_router.removingRetiredAdmin) {
      _reported[result] = authority;
    }
    return result;
  }
}
