import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/repositories/core/repository_sync_result.dart';
import 'package:moliseis/data/repositories/core/repository_sync_state.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:provider/provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  /// Whether to schedule a callback on next frame build or not.
  ///
  /// The callback will be executed exactly once for the lifecycle of this
  /// widget.
  bool _scheduleCallbackOnNextFrame = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w700),
          child: const Text('Molise Is'),
        ),
      ),
      body: Consumer<SyncViewModel>(
        builder: (_, viewModel, _) {
          if (viewModel.state == RepositorySyncState.done) {
            if (viewModel.result == RepositorySyncResult.error) {
              _scheduleCallback(() {
                GoRouter.of(context).refresh();

                showSnackBar(
                  context: context,
                  textContent:
                      "Si è verificato un errore durante l'aggiornamento dei "
                      'contenuti.',
                );
              });
            }

            if (viewModel.result == RepositorySyncResult.majorError) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8.0,
                children: [
                  const Text(
                    'Molise Is necessita di una connessione ad internet per '
                    "l'aggiornamento dei contenuti. Controlla le impostazioni "
                    'di rete.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () async {
                      _scheduleCallbackOnNextFrame = true;
                      await viewModel.synchronize(force: true);
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              );
            }

            if (viewModel.result == RepositorySyncResult.success) {
              _scheduleCallback(() {
                GoRouter.of(context).refresh();
              });
            }
          }

          return const EmptyView.loading(
            text: Text('Aggiornamento dei contenuti in corso...'),
          );
        },
      ),
    );
  }

  void _scheduleCallback(void Function() callback) {
    /// Guards the addPostFrameCallback() from running multiple times
    /// when it is not needed, e.g. when the app Brightness changes
    /// and widgets are rebuilt.
    if (_scheduleCallbackOnNextFrame) {
      /// Schedules a callback to be fired once when the build phase
      /// of this widget has ended.
      ///
      /// Shows a SnackBar signaling a recoverable error occurred
      /// while refreshing the repositories.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        callback();

        _scheduleCallbackOnNextFrame = false;
      });
    }
  }
}
