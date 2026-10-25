import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  SyncViewModel? _owner;
  Object? _pendingSnapshot;
  Object? _authorizedSnapshot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOwner = Provider.of<SyncViewModel>(context);
    if (identical(currentOwner, _owner)) return;
    _owner?.sync.results.removeListener(_onSyncChanged);
    _pendingSnapshot = null;
    _authorizedSnapshot = null;
    _owner = currentOwner;
    currentOwner.sync.results.addListener(_onSyncChanged);
    _observeOutcome(reconcile: true);
  }

  @override
  void dispose() {
    _owner?.sync.results.removeListener(_onSyncChanged);
    _pendingSnapshot = null;
    _owner = null;
    super.dispose();
  }

  void _onSyncChanged() => _observeOutcome(reconcile: false);

  void _observeOutcome({required bool reconcile}) {
    if (!mounted) return;
    final owner = _owner;
    if (owner == null) return;
    final snapshot = owner.sync.results.value;
    if (!snapshot.hasFailure || owner.fatalError) {
      _pendingSnapshot = null;
      return;
    }
    if (identical(snapshot, _authorizedSnapshot) ||
        identical(snapshot, _pendingSnapshot)) {
      return;
    }
    if (reconcile ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      _pendingSnapshot = snapshot;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!identical(_pendingSnapshot, snapshot)) return;
        _pendingSnapshot = null;
        if (owner.sync.isRunningSync.value) return;
        _deliverFeedback(owner, snapshot);
      });
      return;
    }
    // Ordinary terminal publication precedes running=false. Deliver now while
    // this route owns a live context. The messenger survives normal return.
    _deliverFeedback(owner, snapshot);
  }

  void _deliverFeedback(SyncViewModel owner, Object snapshot) {
    if (!mounted) return;
    if (!identical(_owner, owner) ||
        !identical(context.read<SyncViewModel>(), owner) ||
        !identical(owner.sync.results.value, snapshot) ||
        identical(_authorizedSnapshot, snapshot) ||
        owner.fatalError ||
        !owner.sync.results.value.hasFailure ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _authorizedSnapshot = snapshot;
    _pendingSnapshot = null;
    showSnackBar(
      context: context,
      textContent:
          "Si è verificato un errore durante l'aggiornamento dei contenuti",
      type: SnackBarType.error,
    );
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
              listenable: Listenable.merge([
                viewModel.sync.results,
                viewModel.sync.isRunning,
              ]),
              builder: (context, child) {
                if (viewModel.sync.results.value.hasFailure &&
                    viewModel.fatalError) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          viewModel.sync.results.value.unexpectedError != null
                              ? 'Impossibile aggiornare i contenuti. '
                                    'Riprova più tardi.'
                              : 'Molise Is necessita di una connessione ad '
                                    'internet '
                                    "per l'aggiornamento dei contenuti. "
                                    'Controlla le '
                                    'impostazioni di rete.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          viewModel.sync.run(true);
                        },
                        child: const Text('Riprova'),
                      ),
                    ],
                  );
                }

                if (viewModel.sync.isRunningSync.value) {
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
}
