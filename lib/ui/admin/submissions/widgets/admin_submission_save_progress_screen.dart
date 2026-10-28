import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/result_command.dart';

/// Observes an admitted Admin Save; construction never starts remote work.
class AdminSubmissionSaveProgressScreen extends StatelessWidget {
  const AdminSubmissionSaveProgressScreen({
    required this.viewModel,
    required this.sessionId,
    required this.attemptId,
    this.editorTarget,
    super.key,
  });

  final AdminSubmissionEditorViewModel viewModel;
  final String? sessionId;
  final int? attemptId;
  final String? editorTarget;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final matches =
          sessionId != null &&
          sessionId == viewModel.sessionId &&
          attemptId != null &&
          attemptId == viewModel.saveExecutionId;
      final running = matches && viewModel.isSaveRunning;
      final phase = matches ? viewModel.savePhase : AdminSavePhase.idle;
      final activation = viewModel.activation;
      final terminal = !running;
      bool ownsPresentation() =>
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          sessionId != null &&
          sessionId == viewModel.sessionId &&
          attemptId != null &&
          attemptId == viewModel.saveExecutionId &&
          viewModel.isActivationCurrent(activation);
      final router = GoRouter.of(context);
      final routes = router.routerDelegate.currentConfiguration;
      final stack = routes.matches;
      final previous = stack.length > 1 ? stack[stack.length - 2] : null;
      final previousUri = previous is ImperativeRouteMatch
          ? previous.matches.uri
          : routes.uri;
      final previousTarget = previous is ImperativeRouteMatch
          ? previous.matches.pathParameters['id']
          : routes.pathParameters['id'];
      final exactEditorBelow =
          previous is RouteMatch &&
          [
            RouteNames.adminSubmissionNew,
            RouteNames.adminSubmissionEditor,
          ].contains(previous.route.name) &&
          (previousUri.queryParameters['session'] == sessionId ||
              matches &&
                  editorTarget != null &&
                  (previous.route.name == RouteNames.adminSubmissionNew
                      ? editorTarget == 'new'
                      : previousTarget == editorTarget));
      void returnToEditor() {
        if (viewModel.isSaveRunning) return;
        if (matches && !ownsPresentation()) return;
        if (!viewModel.isActivationCurrent(activation)) {
          context.goNamed(RouteNames.adminDashboard);
          return;
        }
        if (exactEditorBelow && context.canPop()) {
          context.pop();
        } else {
          final target = viewModel.submissionId;
          context.goNamed(
            target == null
                ? RouteNames.adminSubmissionNew
                : RouteNames.adminSubmissionEditor,
            pathParameters: target == null ? const {} : {'id': '$target'},
            queryParameters: {'session': ?sessionId},
          );
        }
      }

      return PopScope(
        canPop: terminal && (exactEditorBelow || !matches),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && terminal) returnToEditor();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Salvataggio contributo'),
            leading: terminal
                ? BackButton(onPressed: returnToEditor)
                : const EmptyBox(),
          ),
          body: EmptyView(
            icon: running ? const CircularProgressIndicator() : null,
            text: Text(
              matches &&
                      !running &&
                      viewModel.saveSnapshot.unexpectedError != null
                  ? 'Errore imprevisto. La bozza locale è conservata.'
                  : switch (phase) {
                      AdminSavePhase.checkpoint =>
                        'Salvataggio della bozza locale...',
                      AdminSavePhase.fields => 'Salvataggio del contributo...',
                      AdminSavePhase.adoption =>
                        'Conferma dell’identità del contributo...',
                      AdminSavePhase.upload => 'Caricamento delle foto...',
                      AdminSavePhase.association =>
                        'Associazione delle foto...',
                      AdminSavePhase.completed =>
                        'Contributo salvato. '
                            'Puoi continuare a modificarlo.',
                      AdminSavePhase.partialFailure =>
                        'Salvataggio parziale. '
                            'Il lavoro incompleto è conservato.',
                      AdminSavePhase.unknownOutcome =>
                        'Esito remoto da verificare. '
                            'La bozza locale è conservata.',
                      AdminSavePhase.conflict =>
                        'Il contributo remoto è cambiato. '
                            'Le modifiche locali sono conservate.',
                      AdminSavePhase.failed =>
                        'Salvataggio non completato. '
                            'La bozza locale è conservata.',
                      AdminSavePhase.idle =>
                        'Nessun salvataggio in corso. '
                            'Torna all’editor per continuare.',
                    },
            ),
            action: terminal
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (matches && viewModel.canRequestFieldSettlement)
                        TextButton(
                          onPressed: () {
                            if (!ownsPresentation() ||
                                !viewModel.requestFieldSettlement(
                                  activation: activation,
                                )) {
                              return;
                            }
                            if (!context.mounted ||
                                !viewModel.isActivationCurrent(activation)) {
                              return;
                            }
                            context.replaceNamed(
                              RouteNames.adminSubmissionSaveProgress,
                              queryParameters: {
                                'session': sessionId,
                                'attempt': '${viewModel.saveExecutionId}',
                                'editor': ?editorTarget,
                              },
                            );
                          },
                          child: const Text('Ripristina salvataggio locale'),
                        ),
                      if (matches && viewModel.canRequestSaveReadBack)
                        TextButton(
                          onPressed: () {
                            if (ownsPresentation()) {
                              viewModel.requestSaveReadBack(
                                activation: activation,
                              );
                            }
                          },
                          child: const Text('Verifica esito remoto'),
                        ),
                      // Only an explicit VM admission starts retry.
                      // A new operation gets a new presentation identity.
                      if (matches &&
                          phase != AdminSavePhase.completed &&
                          (viewModel.canRequestSave ||
                              viewModel.canResumeCapturedSave))
                        TextButton(
                          onPressed: () {
                            if (!ownsPresentation() ||
                                !viewModel.requestSave(
                                  activation: activation,
                                  resumeCaptured:
                                      viewModel.canResumeCapturedSave,
                                )) {
                              return;
                            }
                            if (!context.mounted ||
                                !viewModel.isActivationCurrent(activation)) {
                              return;
                            }
                            context.replaceNamed(
                              RouteNames.adminSubmissionSaveProgress,
                              queryParameters: {
                                'session': sessionId,
                                'attempt': '${viewModel.saveExecutionId}',
                                'editor': ?editorTarget,
                              },
                            );
                          },
                          child: const Text('Riprova'),
                        ),
                      TextButton(
                        onPressed: returnToEditor,
                        child: const Text('Torna all’editor'),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
    },
  );
}
