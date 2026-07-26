// Code readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentSubmissionProgressScreen extends StatelessWidget {
  const ContentSubmissionProgressScreen({
    super.key,
    required this.viewModel,
  });

  final ContentSubmissionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final textStyle = context.textTheme.headlineSmall ?? defaultTextStyle;
    final fontSize = textStyle.fontSize;
    final colorScheme = context.theme.colorScheme;

    return ListenableBuilder(
      listenable: viewModel.submit,
      builder: (context, child) {
        final color = _buildColor(colorScheme, viewModel.submit);

        final submitIdle = viewModel.submit.idle;
        final submitRunning = viewModel.submit.running;

        return PopScope(
          // `canPop: false` keeps the OS back gesture and the AppBar chevron
          // on the same code path: with `canPop: true` on completed/error the
          // OS gesture would pop without ever invoking
          // `onPopInvokedWithResult`, bypassing `_clearState` (the original
          // P6 bug). The `maybePop` inside `_handleBack` is a no-op if the
          // route was already popped by the explicit chevron tap path.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleBack(context);
          },
          child: Scaffold(
            appBar: AppBar(
              leading: (submitRunning || submitIdle)
                  ? null
                  : BackButton(
                      onPressed: () => _handleBack(context),
                    ),
            ),
            body: Center(
              child: DefaultTextStyle.merge(
                style: textStyle.copyWith(
                  color: color,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: fontSize == null ? null : fontSize * 2,
                    opticalSize: fontSize == null ? null : fontSize * 4,
                    color: color,
                  ),
                  child: EmptyView(
                    text: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _buildTextDescription(viewModel.submit),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    icon: _buildIcon(viewModel.submit),
                    action: (submitRunning || submitIdle)
                        ? null
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await _clearState(
                                    context,
                                    () => context.goNamed(RouteNames.home),
                                  );
                                },
                                child: const Text('Torna alla home'),
                              ),
                              if (viewModel.submit.completed)
                                _primaryActionButton(
                                  colorScheme: colorScheme,
                                  onPressed: () async => _clearState(
                                    context,
                                    () => _replaceWithFreshForm(context),
                                  ),
                                  child: const Text('Nuovo suggerimento'),
                                )
                              else
                                _primaryActionButton(
                                  colorScheme: colorScheme,
                                  onPressed: () {
                                    unawaited(viewModel.submit.execute());
                                  },
                                  child: const Text('Riprova'),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _buildColor(ColorScheme colorScheme, Command<void> command) =>
      (command.idle || command.running)
      ? colorScheme.onSurfaceVariant
      : command.error
      ? colorScheme.error
      : colorScheme.primary;

  String _buildTextDescription(Command<void> command) =>
      (command.idle || command.running)
      ? 'Invio in corso...'
      : command.error
      ? "Si è verificato un problema durante l'invio"
      : 'Grazie, il suggerimento è stato inviato con successo e verrà '
            'pubblicato a breve';

  Widget _buildIcon(Command<void> command) => (command.idle || command.running)
      ? const CircularProgressIndicator()
      : command.error
      ? const Icon(Symbols.error_circle_rounded_rounded)
      : const Icon(Symbols.check_circle);

  Widget _primaryActionButton({
    required ColorScheme colorScheme,
    void Function()? onPressed,
    required Widget child,
  }) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: colorScheme.tertiary,
      overlayColor: colorScheme.tertiary,
      side: BorderSide(color: colorScheme.tertiary),
    ),
    onPressed: onPressed,
    child: DefaultTextStyle.merge(
      style: TextStyle(color: colorScheme.tertiary),
      child: child,
    ),
  );

  Future<void> _clearState(BuildContext context, void Function()? fn) async {
    // Waits for the command to finish before
    // going back to the main screen to block
    // user from interacting with stale/sent
    // data.
    await viewModel.clear.execute();
    if (context.mounted) {
      fn?.call();
    }
  }

  /// Single entry point for both the AppBar back chevron and the OS back
  /// gesture. Re-resolves `viewModel.submit` at call time so a state
  /// transition arriving between the build that mounted the button and the
  /// tap is honored.
  ///
  /// - `idle` / `running` → no-op (stay blocked, matches P6 in-flight).
  /// - `completed` → `_clearState` then recreate the form fresh (pop the
  ///   progress route, pop the stale form, push a new form). Avoids the
  ///   P1/P4 trap where the preserved form `State` still holds the old
  ///   `TextFormField` text after the in-memory `_state` was wiped.
  /// - `error` → pop once without clearing (P2 intent: let the user modify
  ///   the submission before retrying).
  Future<void> _handleBack(BuildContext context) async {
    final submit = viewModel.submit;
    if (submit.idle || submit.running) {
      return;
    }
    if (submit.completed) {
      await _clearState(context, () => _replaceWithFreshForm(context));
    } else {
      context.pop();
    }
  }

  /// Pops the progress route and the stale form route, then pushes a fresh
  /// `contentSubmission` route on top of explore. The two pops and the push
  /// run synchronously with no pump between them, so no intermediate frame
  /// showing the stale form is ever rendered.
  void _replaceWithFreshForm(BuildContext context) {
    // Cache the router once: the progress screen's `context` becomes
    // unmounted after the second pop, so a second `context.pop()` would
    // resolve the element tree lookup against a stale subtree.
    // `GoRouter.of(context)` captures the single router instance attached to
    // the root navigator key, which survives the progress route's disposal.
    final router = GoRouter.of(context);
    router.pop(); // pop /contentSubmission/uploadProgress
    router.pop(); // pop the stale /contentSubmission form
    unawaited(router.pushNamed(RouteNames.contentSubmission)); // fresh form
  }
}
