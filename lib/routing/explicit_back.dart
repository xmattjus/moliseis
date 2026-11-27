import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';

/// Requests a single departure from the current, committed source of [context].
///
/// Pass [unmatchedError] only for the error supplied by the router's error
/// builder. Protected controls can require a predecessor and keep their
/// existing route exit policy. [onAdmitted] runs just before dispatch.
void requestExplicitBack(
  BuildContext context, {
  GoException? unmatchedError,
  bool predecessorOnly = false,
  VoidCallback? onAdmitted,
}) {
  if (!context.mounted) return;
  final router = GoRouter.maybeOf(context);
  final route = ModalRoute.of(context);
  final page = route?.settings;
  if (router == null ||
      route == null ||
      !route.isCurrent ||
      route.willHandlePopInternally ||
      page is! Page<Object?>) {
    return;
  }

  final configuration = router.routerDelegate.currentConfiguration;
  final root = router.configuration.navigatorKey.currentState;
  var owner = root;
  var matches = configuration.matches;
  var match = matches.lastOrNull;
  var ancestorCanPop = false;
  // GoRouter.pop walks the committed shell chain and prefers its deepest
  // poppable Navigator. Each enclosing shell must also be physically current.
  while (match is ShellRouteMatch) {
    final branch = match.navigatorKey.currentState;
    if (branch == null || owner == null || owner.userGestureInProgress) return;
    final enclosing = ModalRoute.of(branch.context);
    if (enclosing == null ||
        !enclosing.isCurrent ||
        enclosing.navigator != owner) {
      return;
    }
    ancestorCanPop = ancestorCanPop || owner.canPop();
    owner = branch;
    matches = match.matches;
    match = matches.lastOrNull;
  }
  // The current Route can also be a local Navigator push with Page settings.
  // GoRouterState.of only has an association for the router-installed Page.
  if (owner == null ||
      route.navigator != owner ||
      !identical(owner.widget.pages.lastOrNull, page) ||
      owner.userGestureInProgress) {
    return;
  }

  final imperative = match is ImperativeRouteMatch ? match.matches : null;
  final destination = imperative ?? configuration;
  if (unmatchedError != null) {
    if (owner != root || !identical(unmatchedError, destination.error)) return;
  } else {
    if (match is! RouteMatch ||
        destination.isError ||
        !_matchesPage(context, page, match, destination.uri)) {
      return;
    }
  }

  final disposition = route.popDisposition;
  if (!route.isFirst) {
    if (matches.length < 2 || disposition != RoutePopDisposition.pop) return;
    onAdmitted?.call();
    router.pop();
  } else if (matches.length < 2 &&
      !ancestorCanPop &&
      !predecessorOnly &&
      disposition == RoutePopDisposition.bubble &&
      destination.uri.toString() != RoutePaths.home) {
    onAdmitted?.call();
    router.goNamed(RouteNames.home);
  }
}

/// Checks the installed Page's association against the intended live match.
bool _matchesPage(
  BuildContext context,
  Page<Object?> page,
  RouteMatch match,
  Uri uri,
) {
  if (page.key != match.pageKey) return false;
  final GoRouterState installed;
  try {
    installed = GoRouterState.of(context);
    // GoRouterState.of throws GoError when there is no Page association.
    // ignore: avoid_catching_errors
  } on GoError catch (error) {
    if (!error.message.startsWith('There is no GoRouterState above')) rethrow;
    return false;
  }
  // An unassociated Page can also resolve to an ancestor's state.
  if (installed.pageKey != page.key ||
      installed.name != match.route.name ||
      installed.path != match.route.path ||
      installed.matchedLocation != match.matchedLocation ||
      installed.uri != uri) {
    return false;
  }

  // go_router 18.0.2 exposes the inner map directly. Refresh decoding can
  // replace an imperative result with a fresh map before its Page reconciles.
  return match is! ImperativeRouteMatch ||
      identical(installed.pathParameters, match.matches.pathParameters);
}
