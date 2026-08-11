import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

/// Router-level error UI shown for unknown routes and malformed route
/// parameters.
///
/// The router's `errorBuilder` renders this screen for unmatched locations,
/// and route builders render it directly when canonical parameters fail
/// validation. The back control pops the route when one can be popped and
/// falls back to the home tab otherwise.
///
/// This screen is the single logging call site for unknown URIs: every path
/// that renders it emits one error-level [RouteErrorScreenShown] event so
/// unmatched and malformed locations are traceable in Sentry.
/// Navigation that updates this screen in place (rather than recreating its
/// state) also emits an event for the new failure; an equivalent rebuild does
/// not.
class RouteErrorScreen extends StatefulWidget {
  const RouteErrorScreen({required this.uri, required this.error, super.key});

  /// The URI that could not be matched or parsed.
  final Uri uri;

  /// The parsing or validation error, when available.
  final Object? error;

  @override
  State<RouteErrorScreen> createState() => _RouteErrorScreenState();
}

class _RouteErrorScreenState extends State<RouteErrorScreen> {
  @override
  void initState() {
    super.initState();
    _logRouteError();
  }

  @override
  void didUpdateWidget(covariant RouteErrorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // go_router can update this element in place when navigation moves
    // between two invalid values handled by the same route (e.g. two
    // malformed post ids). Log the new failure only when the displayed URI,
    // the error type, or the textual reason actually changes, so an
    // equivalent rebuild (same URI, same error type, same reason) does not
    // double-log.
    if (oldWidget.uri.toString() != widget.uri.toString() ||
        oldWidget.error?.runtimeType != widget.error?.runtimeType ||
        oldWidget.error?.toString() != widget.error?.toString()) {
      _logRouteError();
    }
  }

  /// Emits the event for the failure currently displayed by this screen.
  void _logRouteError() {
    context.read<Logger?>()?.log(
      RouteErrorScreenShown(
        uri: widget.uri.toString(),
        reason: widget.error?.toString(),
      ),
      error: widget.error,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(
        onPressed: () => _popOrGoHome(context),
      ),
      title: const Text('Pagina non trovata'),
    ),
    body: EmptyView.error(
      text: const Text('La pagina richiesta non è stata trovata'),
      action: FilledButton(
        onPressed: () => _popOrGoHome(context),
        child: const Text('Indietro'),
      ),
    ),
  );

  void _popOrGoHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.home);
    }
  }
}
