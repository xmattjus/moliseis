import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentSubmissionProgressScreen extends StatefulWidget {
  const ContentSubmissionProgressScreen({
    super.key,
    required this.viewModel,
  });

  final ContentSubmissionViewModel viewModel;

  @override
  State<ContentSubmissionProgressScreen> createState() =>
      _ContentSubmissionProgressScreenState();
}

class _ContentSubmissionProgressScreenState
    extends State<ContentSubmissionProgressScreen> {
  Future<void>? _clearFuture;

  ContentSubmissionViewModel get _viewModel => widget.viewModel;

  Future<void> _clearOnce() => _clearFuture ??= _viewModel.clear.execute();

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final textStyle = context.textTheme.headlineSmall ?? defaultTextStyle;
    final fontSize = textStyle.fontSize;
    final colorScheme = context.theme.colorScheme;

    return ListenableBuilder(
      listenable: _viewModel.submit,
      builder: (context, child) {
        final submit = _viewModel.submit;
        final color = _buildColor(colorScheme, submit);
        final canPop = !submit.running;

        return PopScope(
          // Only an active upload blocks navigation. A recreated view model is
          // idle after process restoration; that state cannot resume the lost
          // operation and must let the user return to the form.
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            // A completed submission triggers state cleanup after the pop: the
            // form screen below reacts to `viewModel.clear` and resets its
            // fields. The viewModel outlives this route, so the popped
            // `BuildContext` is never used here. Idle and error pops preserve
            // the editable form state.
            if (submit.completed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_clearOnce());
              });
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: canPop
                  ? BackButton(onPressed: () => context.pop())
                  : const EmptyBox(),
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
                        _buildTextDescription(submit),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    icon: _buildIcon(submit),
                    action: submit.running
                        ? null
                        : submit.idle
                        ? _primaryActionButton(
                            colorScheme: colorScheme,
                            onPressed: () => context.pop(),
                            child: const Text('Torna al modulo'),
                          )
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
                              if (submit.completed)
                                _primaryActionButton(
                                  colorScheme: colorScheme,
                                  onPressed: () => context.pop(),
                                  child: const Text('Nuovo suggerimento'),
                                )
                              else
                                _primaryActionButton(
                                  colorScheme: colorScheme,
                                  onPressed: () {
                                    unawaited(submit.execute());
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
      command.error
      ? colorScheme.error
      : command.completed
      ? colorScheme.primary
      : colorScheme.onSurfaceVariant;

  String _buildTextDescription(Command<void> command) => command.running
      ? 'Invio in corso...'
      : command.idle
      ? "L'invio è stato interrotto. Torna al modulo per controllare i dati "
            'prima di riprovare.'
      : command.error
      ? "Si è verificato un problema durante l'invio"
      : 'Grazie, il suggerimento è stato inviato con successo e verrà '
            'pubblicato a breve';

  Widget _buildIcon(Command<void> command) => command.running
      ? const CircularProgressIndicator()
      : command.idle
      ? const Icon(Symbols.upload)
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
    await _clearOnce();
    if (context.mounted) {
      fn?.call();
    }
  }
}
