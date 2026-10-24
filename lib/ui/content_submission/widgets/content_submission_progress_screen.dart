import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

/// Progress screen shown during and after content submission.
///
/// Displays an animated status icon and message reflecting the current state
/// of the current submission snapshot (running, idle, error, or completed).
/// While an
/// upload or local finalization runs, navigation is blocked. Session retirement
/// remains owned by the submission lifecycle in the ViewModel.
class ContentSubmissionProgressScreen extends StatefulWidget {
  /// Creates the submission progress screen.
  ///
  /// [viewModel] owns the submission command and submit state. The screen
  /// observes it live and never starts a new upload itself.
  const ContentSubmissionProgressScreen({required this.viewModel, super.key});

  /// ViewModel providing the current submission command state.
  final ContentSubmissionViewModel viewModel;

  @override
  State<ContentSubmissionProgressScreen> createState() =>
      _ContentSubmissionProgressScreenState();
}

class _ContentSubmissionProgressScreenState
    extends State<ContentSubmissionProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final textStyle = context.textTheme.headlineSmall ?? defaultTextStyle;
    final fontSize = textStyle.fontSize;
    final colorScheme = context.theme.colorScheme;

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        final snapshot = viewModel.submitSnapshot;
        final clientSubmissionId = viewModel.state.clientSubmissionId;
        final running = viewModel.isSubmitting || snapshot.isRunning;
        final finalizationPending = viewModel.submissionFinalizationPending;
        final canRetryImmediately = viewModel.canRetrySubmissionImmediately;
        final color = snapshot.hasFailure
            ? colorScheme.error
            : snapshot.completed
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
        final canPop = !running && !finalizationPending;
        void exit({bool home = false}) => _exitPresentation(
          viewModel,
          clientSubmissionId,
          snapshot,
          home: home,
        );

        return PopScope(
          // A recreated ViewModel is idle after process restoration; that
          // state cannot resume the lost operation and must let the user
          // return to the form.
          canPop: canPop,
          onPopInvokedWithResult: (_, _) {},
          child: Scaffold(
            appBar: AppBar(
              leading: canPop ? BackButton(onPressed: exit) : const EmptyBox(),
            ),
            body: Center(
              child: DefaultTextStyle.merge(
                style: textStyle.copyWith(color: color),
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
                        _buildTextDescription(
                          running: running,
                          idle: snapshot.idle,
                          failed: snapshot.hasFailure,
                          unexpected: snapshot.unexpectedError != null,
                          finalizationPending: finalizationPending,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    icon: _buildIcon(
                      running: running,
                      idle: snapshot.idle,
                      failed: snapshot.hasFailure,
                    ),
                    action: running
                        ? null
                        : snapshot.idle
                        ? _primaryActionButton(
                            colorScheme: colorScheme,
                            onPressed: exit,
                            child: const Text('Torna al modulo'),
                          )
                        : canRetryImmediately
                        ? _primaryActionButton(
                            colorScheme: colorScheme,
                            onPressed: () {
                              if (!_isCurrentPresentation(
                                    viewModel,
                                    clientSubmissionId,
                                    snapshot,
                                  ) ||
                                  !viewModel.canRetrySubmissionImmediately) {
                                return;
                              }
                              viewModel.requestSubmit();
                            },
                            child: const Text('Riprova'),
                          )
                        : finalizationPending
                        ? null
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () => exit(home: true),
                                child: const Text('Torna alla home'),
                              ),
                              if (snapshot.completed)
                                _primaryActionButton(
                                  colorScheme: colorScheme,
                                  onPressed: exit,
                                  child: const Text('Nuovo suggerimento'),
                                )
                              else
                                _primaryActionButton(
                                  colorScheme: colorScheme,
                                  onPressed: exit,
                                  child: const Text('Torna al modulo'),
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

  void _exitPresentation(
    ContentSubmissionViewModel owner,
    String clientSubmissionId,
    Object snapshot, {
    required bool home,
  }) {
    if (!mounted) return;
    if (!_isCurrentPresentation(owner, clientSubmissionId, snapshot) ||
        owner.submissionFinalizationPending) {
      return;
    }
    if (home) {
      context.goNamed(RouteNames.home);
    } else {
      context.pop();
    }
  }

  bool _isCurrentPresentation(
    ContentSubmissionViewModel owner,
    String clientSubmissionId,
    Object snapshot,
  ) {
    if (!mounted) return false;
    final providedOwner = context.read<ContentSubmissionViewModel?>();
    if ((providedOwner != null && !identical(providedOwner, owner)) ||
        !identical(widget.viewModel, owner) ||
        owner.state.clientSubmissionId != clientSubmissionId ||
        !identical(owner.submitSnapshot, snapshot) ||
        owner.isSubmitting ||
        owner.submitSnapshot.isRunning) {
      return false;
    }
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  String _buildTextDescription({
    required bool running,
    required bool idle,
    required bool failed,
    required bool unexpected,
    required bool finalizationPending,
  }) => running
      ? 'Invio in corso...'
      : idle
      ? "L'invio è stato interrotto. Torna al modulo per controllare i dati "
            'prima di riprovare.'
      : failed && finalizationPending
      ? 'Il suggerimento è stato inviato, ma non è stato possibile '
            'completare il salvataggio locale. Riprova senza inviare di nuovo.'
      : unexpected
      ? "Si è verificato un problema imprevisto durante l'invio"
      : failed
      ? "Si è verificato un problema durante l'invio"
      : 'Grazie, il suggerimento è stato inviato con successo e verrà '
            'pubblicato a breve';

  Widget _buildIcon({
    required bool running,
    required bool idle,
    required bool failed,
  }) => running
      ? const CircularProgressIndicator()
      : idle
      ? const Icon(Symbols.upload)
      : failed
      ? const Icon(Symbols.error_circle_rounded_rounded)
      : const Icon(Symbols.check_circle);

  Widget _primaryActionButton({
    required ColorScheme colorScheme,
    required Widget child,
    void Function()? onPressed,
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
