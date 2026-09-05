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

/// Progress screen shown during and after content submission.
///
/// Displays an animated status icon and message reflecting the current state
/// of the submission [Command] (running, idle, error, or completed). While an
/// upload or local finalization runs, navigation is blocked. Session retirement
/// remains owned by the submission lifecycle in the ViewModel.
class ContentSubmissionProgressScreen extends StatefulWidget {
  /// Creates the submission progress screen.
  ///
  /// [viewModel] owns the submission command and submit state. The screen
  /// observes it live and never starts a new upload itself.
  const ContentSubmissionProgressScreen({
    super.key,
    required this.viewModel,
  });

  /// ViewModel providing the current submission command state.
  final ContentSubmissionViewModel viewModel;

  @override
  State<ContentSubmissionProgressScreen> createState() =>
      _ContentSubmissionProgressScreenState();
}

class _ContentSubmissionProgressScreenState
    extends State<ContentSubmissionProgressScreen> {
  ContentSubmissionViewModel get _viewModel => widget.viewModel;

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
        final finalizationPending = _viewModel.submissionFinalizationPending;
        final finalizationError = submit.error && finalizationPending;
        final color = _buildColor(colorScheme, submit);
        final canPop = !submit.running && !finalizationPending;

        return PopScope(
          // A recreated ViewModel is idle after process restoration; that
          // state cannot resume the lost operation and must let the user
          // return to the form.
          canPop: canPop,
          onPopInvokedWithResult: (_, _) {},
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
                        _buildTextDescription(submit, finalizationPending),
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
                        : finalizationError
                        ? _primaryActionButton(
                            colorScheme: colorScheme,
                            onPressed: () => unawaited(submit.execute()),
                            child: const Text('Riprova'),
                          )
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    context.goNamed(RouteNames.home),
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

  String _buildTextDescription(
    Command<void> command,
    bool finalizationPending,
  ) => command.running
      ? 'Invio in corso...'
      : command.idle
      ? "L'invio è stato interrotto. Torna al modulo per controllare i dati "
            'prima di riprovare.'
      : command.error && finalizationPending
      ? 'Il suggerimento è stato inviato, ma non è stato possibile '
            'completare il salvataggio locale. Riprova senza inviare di nuovo.'
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
}
