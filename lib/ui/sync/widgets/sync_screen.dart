import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:provider/provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  // Whether to schedule a callback on next frame build or not.
  bool _scheduleCallbackOnNextFrame = true;

  late final SyncViewModel _syncViewModel;

  @override
  void initState() {
    super.initState();
    _syncViewModel = context.read<SyncViewModel>();
    _syncViewModel.sync.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    _syncViewModel.sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (_syncViewModel.sync.error && !_syncViewModel.fatalError) {
      _scheduleCallback(() {
        if (!mounted) return;
        showSnackBar(
          context: context,
          textContent:
              "Si è verificato un errore durante l'aggiornamento dei "
              'contenuti',
          type: SnackBarType.error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyles(context).surface,
      child: Scaffold(
        appBar: AppBar(
          title: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w700),
            child: const Text('Molise Is'),
          ),
        ),
        body: Consumer<SyncViewModel>(
          builder: (_, viewModel, _) {
            return ListenableBuilder(
              listenable: viewModel.sync,
              builder: (context, child) {
                if (viewModel.sync.error && viewModel.fatalError) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Molise Is necessita di una connessione ad internet '
                          "per l'aggiornamento dei contenuti. Controlla le "
                          'impostazioni di rete.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _scheduleCallbackOnNextFrame = true;
                          unawaited(viewModel.sync.execute(true));
                        },
                        child: const Text('Riprova'),
                      ),
                    ],
                  );
                }

                if (viewModel.sync.running) {
                  return const EmptyView.loading(
                    text: Text('Aggiornamento dei contenuti in corso...'),
                  );
                }

                // The router leaves /sync for every non-running, non-fatal
                // state. Avoid showing a misleading spinner during that frame.
                return const EmptyBox();
              },
            );
          },
        ),
      ),
    );
  }

  void _scheduleCallback(void Function() callback) {
    // Guards the addPostFrameCallback() from running multiple times
    // when it is not needed, e.g. when the app Brightness changes
    // and widgets are rebuilt.
    if (_scheduleCallbackOnNextFrame) {
      // Schedules a callback to be fired once when the build phase
      // of this widget has ended.
      //
      // Shows a SnackBar signaling a recoverable error occurred
      // while refreshing the repositories.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        callback();

        _scheduleCallbackOnNextFrame = false;
      });
    }
  }
}
