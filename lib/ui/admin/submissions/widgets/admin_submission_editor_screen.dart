import 'dart:async' show scheduleMicrotask, unawaited;
import 'dart:io';

import 'package:command_it/command_it.dart' as commands;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_location_editor.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_recovery_panel.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_button.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Form screen for creating and editing a moderation submission.
class AdminSubmissionEditorScreen extends StatefulWidget {
  /// Creates an editor backed by application-owned [viewModel] state.
  const AdminSubmissionEditorScreen({
    required this.viewModel,
    this.onBack,
    this.onModerationClose,
    super.key,
  });

  /// Editor state and commands for this route visit.
  final AdminSubmissionEditorViewModel viewModel;

  /// Explicit Back enters the owning route policy.
  final VoidCallback? onBack;

  /// Allows only the consumed, source-qualified successful moderation effect.
  final bool Function(AdminDraftActivation?, String, int?)? onModerationClose;

  @override
  State<AdminSubmissionEditorScreen> createState() =>
      _AdminSubmissionEditorScreenState();
}

class _AdminSubmissionEditorScreenState
    extends State<AdminSubmissionEditorScreen> {
  final _eventTargetController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();
  final GlobalKey _contentTargetKey = GlobalKey();
  final GlobalKey _temporalTargetKey = GlobalKey();
  final GlobalKey _verificationTargetKey = GlobalKey();
  final GlobalKey _sourceTargetKey = GlobalKey();
  final GlobalKey _overwriteTargetKey = GlobalKey();
  int _revealCoordinatesRevision = 0;
  String? _validationMessage;
  VoidCallback? _validationReveal;
  final _consumed = <String, int?>{};
  late AdminSubmissionEditorViewModel _owner;
  AdminDraftActivation? _boundActivation;
  var _statusDialogOpen = false;
  ModalRoute<dynamic>? _statusDialogRoute;
  var _statusDialogRevoked = false;
  var _dialogSession = 0;
  var _routeExited = false;

  @override
  void initState() {
    super.initState();
    _bind(widget.viewModel);
  }

  @override
  void didUpdateWidget(covariant AdminSubmissionEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      _owner.removeListener(_onOwnerChanged);
      _bind(widget.viewModel);
    }
  }

  void _bind(AdminSubmissionEditorViewModel owner) {
    _retireStatusDialog();
    _validationMessage = null;
    _validationReveal = null;
    _owner = owner;
    _boundActivation = owner.activation;
    _routeExited = false;
    _dialogSession++;
    _statusDialogOpen = false;
    _statusDialogRoute = null;
    _statusDialogRevoked = false;
    // Existing terminals are historical, not new effects for this binding.
    _consumed
      ..clear()
      ..addAll({
        'save': owner.saveExecutionId,
        'reject': owner.rejectExecutionId,
        'promote': owner.promoteExecutionId,
        'link': owner.linkExecutionId,
        'apply': owner.applyExecutionId,
        'addAsset': owner.addAssetExecutionId,
        'deleteAsset': owner.deleteAssetExecutionId,
      });
    // A running execution has not yet delivered its terminal to this binding.
    if (owner.saveSnapshot.isRunning) _consumed.remove('save');
    if (owner.rejectSnapshot.isRunning) _consumed.remove('reject');
    if (owner.promoteSnapshot.isRunning) _consumed.remove('promote');
    if (owner.linkSnapshot.isRunning) _consumed.remove('link');
    if (owner.applySnapshot.isRunning) _consumed.remove('apply');
    if (owner.addAssetSnapshot.isRunning) _consumed.remove('addAsset');
    if (owner.deleteAssetSnapshot.isRunning) _consumed.remove('deleteAsset');
    owner.addListener(_onOwnerChanged);
    _syncEventTarget();
  }

  bool _owns(AdminSubmissionEditorViewModel owner) =>
      mounted &&
      identical(_owner, owner) &&
      identical(widget.viewModel, owner) &&
      !owner.isDisposed &&
      owner.isActivationCurrent(_boundActivation) &&
      !_routeExited;

  bool _hasRouteEffectAuthority(AdminSubmissionEditorViewModel owner) =>
      _owns(owner) && ModalRoute.of(context)?.isCurrent == true;

  void _observeStatusDialogRoute(BuildContext dialogContext, int session) {
    if (!mounted || session != _dialogSession) return;
    // ModalRoute.of subscribes this dialog builder to isCurrent changes. A
    // covering page permanently revokes this session, including an old latch.
    _statusDialogRoute = ModalRoute.of(dialogContext);
    _revokeCoveredStatusDialog();
  }

  void _revokeCoveredStatusDialog() {
    final route = _statusDialogRoute;
    // Normal dialog dismissal makes the route inactive, not covered.
    if (route != null && route.isActive && !route.isCurrent) {
      _statusDialogRevoked = true;
    }
  }

  bool _hasStatusDialogEffectAuthority(AdminSubmissionEditorViewModel owner) {
    if (!_owns(owner) || !_statusDialogOpen) return false;
    _revokeCoveredStatusDialog();
    return !_statusDialogRevoked && _statusDialogRoute?.isCurrent == true;
  }

  void _retireStatusDialog() {
    final dialog = _statusDialogRoute;
    final navigator = dialog?.navigator;
    if (dialog == null || navigator == null) return;
    // Remove only this obsolete dialog, after Navigator's current dispatch.
    // Captured route/navigator references need no disposed State context.
    scheduleMicrotask(() {
      if (navigator.mounted && dialog.isActive) navigator.removeRoute(dialog);
    });
  }

  @override
  void dispose() {
    _retireStatusDialog();
    _dialogSession++;
    _owner.removeListener(_onOwnerChanged);
    _eventTargetController.dispose();
    super.dispose();
  }

  void _syncEventTarget() {
    if (!_owns(_owner)) return;
    final target = _owner.targetEventId;
    if (int.tryParse(_eventTargetController.text) == target) return;
    final text = target?.toString() ?? '';
    _eventTargetController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _request(AdminSubmissionEditorViewModel owner, void Function() action) {
    if (_owns(owner)) action();
  }

  void _closeEditor(
    AdminSubmissionEditorViewModel owner,
    String lane,
    int? execution,
  ) {
    if (!_hasRouteEffectAuthority(owner)) return;
    final close = widget.onModerationClose;
    if (close != null) {
      _routeExited = close(_boundActivation, lane, execution);
    } else {
      _routeExited = true;
      context.pop(true);
    }
  }

  void _consume<T>(
    AdminSubmissionEditorViewModel owner,
    String lane,
    int? executionId,
    commands.CommandResult<void, Result<T>?> snapshot,
    void Function() effect,
  ) {
    if (!_owns(owner) ||
        executionId == null ||
        snapshot.isRunning ||
        snapshot.idle ||
        _consumed[lane] == executionId) {
      return;
    }
    _consumed[lane] = executionId;
    // Hidden terminals are consumed, never queued for replay on return. Only
    // Save may feed its editor's currently authoritative confirmation dialog.
    if (_hasRouteEffectAuthority(owner) ||
        lane == 'save' && _hasStatusDialogEffectAuthority(owner)) {
      effect();
    }
  }

  void _onOwnerChanged() {
    final owner = _owner;
    final next = owner.activation;
    final previous = _boundActivation;
    if (next != null &&
        previous != null &&
        previous.owner.submissionId == null &&
        next.owner.submissionId != null &&
        previous.owner.accountId == next.owner.accountId &&
        previous.owner.sessionId == next.owner.sessionId) {
      // Adoption changes only the target. Old callbacks retain old tokens.
      _boundActivation = next;
    }
    if (!_owns(owner)) return;
    _syncEventTarget();
    _consume(owner, 'save', owner.saveExecutionId, owner.saveSnapshot, () {
      // Save never closes the editor, including a completion under a dialog.
      if (owner.saveSnapshot.hasFailure) {
        _showModerationError(owner.saveSnapshot.data);
      }
    });
    _consume(
      owner,
      'reject',
      owner.rejectExecutionId,
      owner.rejectSnapshot,
      () => _handleRejectCompleted(owner),
    );
    _consume(
      owner,
      'promote',
      owner.promoteExecutionId,
      owner.promoteSnapshot,
      () => _handleResolutionCompleted(
        owner,
        owner.promoteSnapshot,
        'promote',
        owner.promoteExecutionId,
      ),
    );
    _consume(
      owner,
      'link',
      owner.linkExecutionId,
      owner.linkSnapshot,
      () => _handleResolutionCompleted(
        owner,
        owner.linkSnapshot,
        'link',
        owner.linkExecutionId,
      ),
    );
    _consume(
      owner,
      'apply',
      owner.applyExecutionId,
      owner.applySnapshot,
      () => _handleResolutionCompleted(
        owner,
        owner.applySnapshot,
        'apply',
        owner.applyExecutionId,
      ),
    );
    _consume(
      owner,
      'addAsset',
      owner.addAssetExecutionId,
      owner.addAssetSnapshot,
      () {
        if (owner.addAssetSnapshot.hasFailure) _showModerationError(null);
      },
    );
    _consume(
      owner,
      'deleteAsset',
      owner.deleteAssetExecutionId,
      owner.deleteAssetSnapshot,
      () {
        if (owner.deleteAssetSnapshot.hasFailure) _showModerationError(null);
      },
    );
  }

  void _handleResolutionCompleted<T>(
    AdminSubmissionEditorViewModel owner,
    commands.CommandResult<void, Result<T>?> snapshot,
    String lane,
    int? execution,
  ) {
    if (!_owns(owner)) return;
    if (snapshot.completed) {
      _closeEditor(owner, lane, execution);
    } else if (snapshot.hasFailure) {
      _showModerationError(snapshot.data);
    }
  }

  void _showModerationError(Result<dynamic>? result) {
    if (!_hasRouteEffectAuthority(_owner) &&
        !_hasStatusDialogEffectAuthority(_owner)) {
      return;
    }
    final message = switch (result) {
      Error(:final AdminContentSubmissionApiException error) =>
        _moderationErrorMessage(error.code),
      _ => null,
    };
    if (message == null) {
      showSnackBarGenericError(context: context);
    } else {
      showSnackBar(
        context: context,
        textContent: message,
        type: SnackBarType.error,
      );
    }
  }

  void _handleRejectCompleted(AdminSubmissionEditorViewModel owner) {
    if (!_owns(owner)) return;
    final reject = owner.rejectSnapshot;
    if (reject.completed) {
      _closeEditor(owner, 'reject', owner.rejectExecutionId);
    } else if (reject.hasFailure) {
      _showModerationError(reject.data);
    }
  }

  /// Maps known promotion failure codes to actionable Italian copy; unknown
  /// codes fall back to the generic snackbar.
  String? _moderationErrorMessage(String? code) => switch (code
      ?.toUpperCase()) {
    'ADMIN_PROFILE_INCOMPLETE' =>
      "Il profilo amministratore richiede un nome e un'email validi.",
    'COORDINATES_REQUIRED' ||
    'INVALID_COORDINATES' ||
    'PROMOTION_COORDINATES_REQUIRED' ||
    'PROMOTION_INVALID_COORDINATES' =>
      'Imposta coordinate valide e salva prima di pubblicare.',
    'CITY_NOT_FOUND' || 'PROMOTION_CITY_NOT_FOUND' =>
      'La città non corrisponde a una località disponibile. '
          'Correggila e salva.',
    'PROMOTION_PLACE_HAS_EVENT_DATES' =>
      "Rimuovi le date dell'evento e salva prima di pubblicare "
          'come luogo.',
    'START_DATE_REQUIRED' ||
    'NOT_EVENT_SUBMISSION' ||
    'PROMOTION_START_DATE_REQUIRED' =>
      'Imposta una data di inizio e salva prima di pubblicare '
          "l'evento.",
    'INVALID_DATE_RANGE' || 'PROMOTION_INVALID_DATE_RANGE' =>
      "Correggi le date dell'evento e salva prima di pubblicare.",
    'PROMOTION_INVALID_NAME' =>
      'Inserisci un nome valido e salva prima di pubblicare.',
    'PROMOTION_INVALID_ASSET' =>
      'Una foto associata non è valida e impedisce la pubblicazione.',
    'PROMOTION_CATEGORY_REQUIRED' =>
      'Seleziona una categoria e salva '
          'prima di pubblicare.',
    'PROMOTION_TARGET_CONFLICT' =>
      'Il contributo è già stato pubblicato con un tipo diverso.',
    'PROMOTION_SOURCE_ALREADY_LINKED' || 'SOURCE_ALREADY_LINKED' =>
      'La fonte è già collegata. Usa Collega o Applica aggiornamento.',
    'SOURCE_CHANGED' =>
      'La fonte è cambiata. Rileggi la versione corrente e conferma di nuovo.',
    'EVENT_CHANGED' || 'SUBMISSION_CHANGED' =>
      'I dati sono cambiati. Ricarica l’anteprima prima di applicare.',
    'NORMALIZATION_MISMATCH' =>
      'La versione della fonte richiede una migrazione. Contatta la redazione.',
    'RELINK_CONFLICT' || 'TARGET_CONFLICT' =>
      'Il contributo è collegato a un altro evento. Ricarica i dati.',
    'LINK_REQUIRED' => 'Collega prima la fonte a un evento esistente.',
    'EVENT_INACTIVE' ||
    'EVENT_NOT_FOUND' => 'L’evento non è disponibile. Cerca un evento attivo.',
    'INVALID_GROUPS' => 'Anteprima non valida. Ricaricala prima di applicare.',
    'INVALID_STATUS_TRANSITION' =>
      'Il contributo non è più in attesa. Ricarica la schermata.',
    _ => null,
  };

  /// Closes the keyboard so an already-focused input cannot swallow edits
  /// after the request snapshot pops the route on success.
  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Durable linkage summary shown for promoted accepted submissions, e.g.
  /// "Pubblicato come evento · ID 123".
  String _publishedAs(AdminSubmissionPromotion promotion) {
    final kind = switch (promotion.target) {
      AdminPromotionTarget.event => 'evento',
      AdminPromotionTarget.place => 'luogo',
    };
    return 'Pubblicato come $kind · ID ${promotion.entityId}';
  }

  static void _dismissDialog(BuildContext dialogContext, [bool? result]) {
    if (!dialogContext.mounted ||
        ModalRoute.of(dialogContext)?.isCurrent != true) {
      return;
    }
    Navigator.of(dialogContext).pop(result);
  }

  Future<void> _confirmPublish(
    AdminSubmissionEditorViewModel viewModel,
    AdminPromotionTarget target,
  ) async {
    if (!mounted) return;
    final activation = viewModel.activation;

    if (!_hasRouteEffectAuthority(viewModel) ||
        viewModel.operationRunning ||
        _statusDialogOpen) {
      return;
    }
    final revision = viewModel.editorRevision;
    final session = ++_dialogSession;
    _unfocus();
    _statusDialogOpen = true;
    _statusDialogRoute = null;
    _statusDialogRevoked = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          _observeStatusDialogRoute(context, session);
          if (!_owns(viewModel)) return const SizedBox.shrink();
          final question = switch (target) {
            AdminPromotionTarget.event =>
              'Confermi di voler pubblicare questo contributo come evento?',
            AdminPromotionTarget.place =>
              'Confermi di voler pubblicare questo contributo come luogo?',
          };
          return AlertDialog(
            content: Text(question),
            actions: <Widget>[
              TextButton(
                onPressed: () => _dismissDialog(context),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => _dismissDialog(context, true),
                child: const Text('Conferma'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      if (!_hasRouteEffectAuthority(viewModel) ||
          session != _dialogSession ||
          _statusDialogRevoked) {
        return;
      }
      if (confirmed != true ||
          viewModel.operationRunning ||
          revision != viewModel.editorRevision) {
        return;
      }

      _request(
        viewModel,
        () => viewModel.requestPromote(target, activation: activation),
      );
    } finally {
      if (session == _dialogSession && identical(_owner, viewModel)) {
        _statusDialogOpen = false;
        _statusDialogRoute = null;
      }
    }
  }

  Future<void> _confirmReject(AdminSubmissionEditorViewModel viewModel) async {
    if (!mounted) return;
    final activation = viewModel.activation;

    if (!_hasRouteEffectAuthority(viewModel) ||
        viewModel.operationRunning ||
        _statusDialogOpen) {
      return;
    }
    final revision = viewModel.editorRevision;
    final session = ++_dialogSession;
    var ignoreSource = viewModel.ignoreSource;
    _unfocus();
    _statusDialogOpen = true;
    _statusDialogRoute = null;
    _statusDialogRevoked = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          _observeStatusDialogRoute(context, session);
          if (!_owns(viewModel)) return const SizedBox.shrink();
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => !_owns(viewModel)
                ? const SizedBox.shrink()
                : AlertDialog(
                    scrollable: true,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Confermi di voler rifiutare questo contributo?',
                        ),
                        if (viewModel.externalEvent != null) ...[
                          const Text(
                            'Rifiutare una revisione considera quella '
                            'revisione sorgente esaminata e scartata. '
                            'Le modifiche ancora presenti in revisioni '
                            'future non vengono riproposte finché il '
                            'provider non modifica nuovamente il '
                            'relativo gruppo.',
                          ),
                          CheckboxListTile(
                            title: const Text(
                              'Ignora anche le revisioni future della fonte',
                            ),
                            subtitle: const Text(
                              'Le revisioni future saranno soppresse '
                              'finché non riattivi la fonte da Fonti '
                              'ignorate.',
                            ),
                            value: ignoreSource,
                            onChanged: (value) => _request(
                              viewModel,
                              () => setDialogState(
                                () => ignoreSource = value ?? false,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => _dismissDialog(context),
                        child: const Text('Annulla'),
                      ),
                      FilledButton(
                        onPressed: () => _dismissDialog(context, true),
                        child: const Text('Conferma'),
                      ),
                    ],
                  ),
          );
        },
      );
      if (!mounted) return;
      if (!_hasRouteEffectAuthority(viewModel) ||
          session != _dialogSession ||
          _statusDialogRevoked) {
        return;
      }
      if (confirmed != true ||
          viewModel.operationRunning ||
          revision != viewModel.editorRevision) {
        return;
      }

      viewModel.setIgnoreSource(ignored: ignoreSource, activation: activation);
      _request(
        viewModel,
        () => viewModel.requestReject(activation: activation),
      );
    } finally {
      if (session == _dialogSession && identical(_owner, viewModel)) {
        _statusDialogOpen = false;
        _statusDialogRoute = null;
      }
    }
  }

  Future<void> _confirmAssetDeletion(
    AdminSubmissionEditorViewModel viewModel,
    int assetId,
  ) async {
    if (!mounted) return;
    final activation = viewModel.activation;

    if (!_hasRouteEffectAuthority(viewModel) || viewModel.operationRunning) {
      return;
    }
    _unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        if (!_owns(viewModel)) return const SizedBox.shrink();
        return AlertDialog(
          content: const Text('Rimuovere questa foto dal suggerimento?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => _dismissDialog(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => _dismissDialog(context, true),
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (!_hasRouteEffectAuthority(viewModel) ||
        confirmed != true ||
        viewModel.operationRunning ||
        !viewModel.assets.any((asset) => asset.id == assetId)) {
      return;
    }
    _request(
      viewModel,
      () => viewModel.requestDeleteAsset(assetId, activation: activation),
    );
  }

  Future<void> _checkpoint(
    AdminSubmissionEditorViewModel owner,
    AdminDraftActivation? activation,
  ) async {
    if (!mounted) return;
    if (!_owns(owner) || !owner.isActivationCurrent(activation)) return;
    final result = await owner.checkpointLocal();
    if (!mounted) return;
    if (!_owns(owner) || !owner.isActivationCurrent(activation)) return;
    if (result is Error<void> && _hasRouteEffectAuthority(owner)) {
      showSnackBarGenericError(context: context);
    }
  }

  void _save(
    AdminSubmissionEditorViewModel owner,
    AdminDraftActivation? activation, {
    bool validate = true,
  }) {
    if (!_owns(owner)) return;
    if (!owner.isActivationCurrent(activation)) return;
    final contentErrors = validate
        ? _formKey.currentState?.validateGranularly()
        : null;
    final locationErrors = validate
        ? _locationFormKey.currentState?.validateGranularly()
        : null;
    final contentOk = !validate || contentErrors?.isEmpty == true;
    final locationOk = !validate || locationErrors?.isEmpty == true;
    final eventTimeOk = !validate || owner.validateEventTimeForSave();
    if (!contentOk || !locationOk || !eventTimeOk) {
      final location = contentOk && !locationOk;
      final field = !contentOk
          ? contentErrors?.firstOrNull
          : locationErrors?.firstOrNull;
      setState(() {
        _validationMessage = !contentOk
            ? 'Controlla i campi del contributo.'
            : !locationOk
            ? 'Correggi le coordinate della posizione.'
            : 'Controlla data e ora dell’evento.';
        _validationReveal = () {
          if (!_hasRouteEffectAuthority(owner) ||
              !owner.isActivationCurrent(activation)) {
            return;
          }
          if (location) setState(() => _revealCoordinatesRevision++);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!_hasRouteEffectAuthority(owner) ||
                !owner.isActivationCurrent(activation)) {
              return;
            }
            final target = field?.mounted == true
                ? field!.context
                : !eventTimeOk
                ? _temporalTargetKey.currentContext
                : location
                ? _locationFormKey.currentContext
                : _formKey.currentContext;
            if (target != null && target.mounted) {
              Scrollable.ensureVisible(
                target,
                alignment: .5,
                duration: Durations.medium2,
              );
            }
          });
        };
      });
      _validationReveal?.call();
      return;
    }
    if (contentOk && locationOk && eventTimeOk) {
      setState(() {
        _validationMessage = null;
        _validationReveal = null;
      });
      _unfocus();
      if (!owner.requestSave(
        activation: activation,
        resumeCaptured: !validate,
      )) {
        return;
      }
      _openSaveProgress(owner);
    }
  }

  void _openSaveProgress(AdminSubmissionEditorViewModel owner) {
    if (!mounted) return;
    if (!_owns(owner)) return;
    final session = owner.sessionId;
    if (session == null) return;
    unawaited(
      context.pushNamed(
        RouteNames.adminSubmissionSaveProgress,
        queryParameters: {
          'session': session,
          'attempt': '${owner.saveExecutionId}',
          'editor': '${owner.submissionId ?? 'new'}',
        },
      ),
    );
  }

  String _recoveryMessage(AdminEditorRecoveryState state) => switch (state) {
    AdminEditorRecoveryState.conflict =>
      'Il contributo remoto è cambiato. Le modifiche locali sono conservate. '
          'Confronta le versioni prima di proseguire.',
    AdminEditorRecoveryState.finalized =>
      'Il contributo non è più in attesa. Il lavoro locale è conservato; '
          'puoi salvare la bozza locale e tornare alla lista.',
    AdminEditorRecoveryState.missing =>
      'Il contributo remoto non è disponibile. Il lavoro locale è conservato. '
          'Puoi verificarne di nuovo lo stato o tornare alla lista.',
    AdminEditorRecoveryState.denied =>
      'Accesso al contributo non autorizzato. Il salvataggio remoto è sospeso. '
          'Verifica l’accesso prima di riprovare; '
          'il lavoro locale è conservato.',
    AdminEditorRecoveryState.incompatible =>
      'La versione remota non è utilizzabile. '
          'Nessun campo locale è stato sostituito. '
          'Puoi riprovare o tornare alla lista.',
    AdminEditorRecoveryState.unresolvedIntent =>
      'L’esito del salvataggio precedente è ancora da verificare. '
          'Le modifiche locali sono conservate: verifica l’esito remoto '
          'prima di un nuovo salvataggio.',
    AdminEditorRecoveryState.none || AdminEditorRecoveryState.retryable =>
      'Impossibile caricare il contributo. Il lavoro locale è conservato. '
          'Puoi riprovare o tornare alla lista.',
  };

  String _mergeLabel(String name) => switch (name) {
    'name' => 'Nome',
    'description' => 'Descrizione',
    'location' => 'Posizione',
    'schedule' => 'Date e orari',
    'category' => 'Categoria',
    _ => name,
  };

  List<AdminEventMergeGroup> _orderedGroups(
    List<AdminEventMergeGroup> groups,
  ) => [
    ...groups.where((g) => g.overwrite),
    ...groups.where(
      (g) =>
          !g.overwrite && (g.apply || g.providerChanged || g.moderatorChanged),
    ),
    ...groups.where(
      (g) =>
          !g.overwrite && !g.apply && !g.providerChanged && !g.moderatorChanged,
    ),
  ];

  void _revealEvidence(
    AdminSubmissionEditorViewModel owner,
    AdminDraftActivation? activation,
    GlobalKey target,
    bool Function() current,
  ) {
    if (!_hasRouteEffectAuthority(owner) ||
        !owner.isActivationCurrent(activation) ||
        !current()) {
      return;
    }
    final targetContext = target.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(targetContext, duration: Durations.medium2);
    }
  }

  Widget _decisionArea(
    AdminSubmissionEditorViewModel viewModel,
    AdminDraftActivation? activation, {
    required bool expanded,
  }) {
    final pending = viewModel.status == AdminSubmissionStatus.pending;
    final recovery =
        viewModel.recoveryState != AdminEditorRecoveryState.none ||
        viewModel.loadSnapshot.hasFailure ||
        viewModel.pendingRecoveryCheckpoint ||
        viewModel.canResumeCapturedSave ||
        viewModel.canRequestSaveReadBack ||
        viewModel.canRequestFieldSettlement ||
        viewModel.canRefreshSaveAuthority;
    final recoverySummary = viewModel.pendingRecoveryCheckpoint
        ? 'I campi remoti accettati non sono ancora nella bozza locale. '
              'Salva la bozza locale prima di aprire un altro contributo.'
        : viewModel.canResumeCapturedSave
        ? 'Puoi riprendere il salvataggio acquisito. '
              'Le modifiche successive restano conservate.'
        : viewModel.canRequestFieldSettlement
        ? 'Completa il ripristino locale prima di proseguire.'
        : viewModel.canRefreshSaveAuthority
        ? 'Ricarica lo stato remoto prima di proseguire.'
        : _recoveryMessage(viewModel.recoveryState);
    final finalized =
        viewModel.status == AdminSubmissionStatus.accepted ||
        viewModel.status == AdminSubmissionStatus.rejected;
    final merge = viewModel.mergePreview;
    final external = viewModel.externalEvent;
    final overwrites = merge?.groups.where((g) => g.overwrite).length ?? 0;
    final linkWorkflow = pending && viewModel.startDate != null;
    final selectedTarget = viewModel.targetEventId;
    final linkSelected = linkWorkflow && selectedTarget != null;
    final save = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
      onPressed: !viewModel.canRequestSave
          ? null
          : () => _save(viewModel, activation),
      icon: const Icon(Symbols.save),
      label: Text(viewModel.isEditMode ? 'Salva modifiche' : 'Crea contributo'),
    );
    final publish = FilledButton.tonal(
      onPressed:
          viewModel.isDirty ||
              !viewModel.canRequestPromote ||
              !viewModel.hasPublishableCategory
          ? null
          : () => unawaited(
              _confirmPublish(
                viewModel,
                viewModel.isEvent
                    ? AdminPromotionTarget.event
                    : AdminPromotionTarget.place,
              ),
            ),
      child: Text(
        viewModel.isEvent ? 'Pubblica come evento' : 'Pubblica come luogo',
      ),
    );
    final link = FilledButton.tonal(
      onPressed: !linkSelected || viewModel.isDirty || !viewModel.canRequestLink
          ? null
          : () => _request(viewModel, () {
              if (viewModel.targetEventId != selectedTarget) return;
              viewModel.requestLink(selectedTarget, activation: activation);
            }),
      child: const Text('Collega a evento'),
    );
    final preview = TextButton(
      onPressed:
          !linkWorkflow ||
              viewModel.isDirty ||
              !viewModel.canRequestPreview ||
              viewModel.targetEventId == null
          ? null
          : () => _request(
              viewModel,
              () => viewModel.requestPreview(activation: activation),
            ),
      child: const Text('Anteprima aggiornamento'),
    );
    final apply = FilledButton(
      onPressed: !viewModel.canRequestApply
          ? null
          : () => _request(viewModel, () {
              if (!identical(viewModel.mergePreview, merge)) return;
              viewModel.requestApply(activation: activation);
            }),
      child: const Text('Applica aggiornamento'),
    );
    final recoveryActions = <Widget>[
      if (viewModel.canRequestFieldSettlement)
        TextButton(
          onPressed: () {
            if (_owns(viewModel) &&
                viewModel.requestFieldSettlement(activation: activation)) {
              _openSaveProgress(viewModel);
            }
          },
          child: const Text('Ripristina salvataggio locale'),
        ),
      if (viewModel.canResumeCapturedSave)
        TextButton(
          onPressed: () => _save(viewModel, activation, validate: false),
          child: const Text('Riprendi salvataggio'),
        ),
      if (viewModel.canRequestSaveReadBack)
        TextButton(
          onPressed: () =>
              viewModel.requestSaveReadBack(activation: activation),
          child: const Text('Verifica esito remoto'),
        ),

      if (viewModel.canRefreshSaveAuthority)
        TextButton(
          key: const ValueKey('admin_recovery_reload'),
          onPressed: () => _request(
            viewModel,
            () => viewModel.requestLoad(activation: activation),
          ),
          child: const Text('Ricarica stato remoto'),
        ),
      if ((viewModel.recoveryState != AdminEditorRecoveryState.none ||
              viewModel.loadSnapshot.hasFailure) &&
          !viewModel.canRefreshSaveAuthority)
        TextButton(
          key: const ValueKey('admin_recovery_reload'),
          onPressed: !viewModel.canRequestLoad
              ? null
              : () => _request(
                  viewModel,
                  () => viewModel.requestLoad(activation: activation),
                ),
          child: const Text('Riprova'),
        ),
      if (viewModel.canCheckpoint)
        TextButton(
          onPressed: () {
            unawaited(_checkpoint(viewModel, activation));
          },
          child: const Text('Salva bozza locale'),
        ),
      if (viewModel.recoveryState != AdminEditorRecoveryState.none ||
          viewModel.loadSnapshot.hasFailure)
        TextButton(
          key: const ValueKey('admin_recovery_return'),
          onPressed: () {
            if (!_hasRouteEffectAuthority(viewModel) ||
                !viewModel.isActivationCurrent(activation)) {
              return;
            }
            context.goNamed(RouteNames.adminDashboard);
          },
          child: const Text('Torna alla lista'),
        ),
    ];
    final actions = <Widget>[];
    Widget? primary;
    if (!viewModel.isEditMode || pending) {
      if (recovery) {
        if (recoveryActions.isNotEmpty) {
          primary = recoveryActions.first;
          actions.addAll(recoveryActions.skip(1));
        }
        actions.add(save);
      } else if (!viewModel.isEditMode || viewModel.isDirty) {
        primary = save;
      } else if (viewModel.isExternalUpdate) {
        primary = merge == null ? preview : apply;
        actions.add(save);
      } else if (linkSelected) {
        primary = link;
        actions.add(save);
      } else {
        primary = publish;
        actions.add(save);
      }
      if (pending) {
        if (!viewModel.isExternalUpdate && !identical(primary, publish)) {
          actions.add(publish);
        }
        if (linkWorkflow && !identical(primary, link)) actions.add(link);
        if (viewModel.isExternalUpdate &&
            linkWorkflow &&
            !identical(primary, preview)) {
          actions.add(preview);
        }
        if (merge != null && !identical(primary, apply)) actions.add(apply);
        actions.add(
          FilledButton.tonal(
            onPressed: viewModel.isDirty || !viewModel.canRequestReject
                ? null
                : () => unawaited(_confirmReject(viewModel)),
            child: const Text('Rifiuta'),
          ),
        );
      }
    } else {
      if (recovery && recoveryActions.isNotEmpty) {
        primary = recoveryActions.first;
        actions.addAll(recoveryActions.skip(1));
      } else {
        actions.addAll(recoveryActions);
      }
    }
    if (!recovery && (!viewModel.isEditMode || pending)) {
      actions.addAll(recoveryActions);
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (viewModel.operationRunning)
                        Text(
                          viewModel.saveSnapshot.isRunning
                              ? 'Salvataggio in corso…'
                              : viewModel.previewSnapshot.isRunning
                              ? 'Preparazione anteprima…'
                              : viewModel.applySnapshot.isRunning
                              ? 'Applicazione aggiornamento…'
                              : viewModel.linkSnapshot.isRunning
                              ? 'Collegamento in corso…'
                              : 'Operazione in corso…',
                          semanticsLabel: 'Operazione in corso',
                        ),
                      if (recovery) Text(recoverySummary),
                      if (finalized)
                        Text(
                          '${viewModel.status?.label ?? "Contributo"} · '
                          'sola lettura',
                        ),
                      if (_validationMessage != null)
                        TextButton.icon(
                          key: const ValueKey('admin_validation_feedback'),
                          onPressed: _validationReveal,
                          icon: const Icon(Icons.error_outline),
                          label: Text(_validationMessage!),
                        ),
                      if (pending && viewModel.isDirty)
                        const Text(
                          'Salva le modifiche prima di moderare. '
                          'Il salvataggio non pubblica.',
                        ),
                      if (pending &&
                          !viewModel.isDirty &&
                          !viewModel.hasPublishableCategory &&
                          !viewModel.isExternalUpdate)
                        TextButton(
                          onPressed: () => _revealEvidence(
                            viewModel,
                            activation,
                            _contentTargetKey,
                            () => true,
                          ),
                          child: const Text(
                            'Seleziona una categoria e salva '
                            'prima di pubblicare.',
                          ),
                        ),
                      if (viewModel.isExternalUpdate && !linkWorkflow)
                        TextButton(
                          onPressed: () => _revealEvidence(
                            viewModel,
                            activation,
                            _temporalTargetKey,
                            () => true,
                          ),
                          child: const Text(
                            'Completa la data di inizio dell’evento.',
                          ),
                        )
                      else if (viewModel.isExternalUpdate &&
                          selectedTarget == null)
                        TextButton(
                          onPressed: () => _revealEvidence(
                            viewModel,
                            activation,
                            _verificationTargetKey,
                            () => true,
                          ),
                          child: const Text(
                            'Seleziona l’evento da confrontare.',
                          ),
                        ),
                      if (identical(primary, link))
                        Text(
                          'Collega la proposta all’evento '
                          '#${viewModel.targetEventId}, '
                          'senza sovrascriverne i contenuti.',
                        ),
                      if (primary is ButtonStyleButton)
                        FilledButton(
                          key: primary.key,
                          onPressed: primary.onPressed,
                          child: primary.child,
                        )
                      else
                        ?primary,
                      if (overwrites > 0) ...[
                        Text(
                          overwrites == 1
                              ? '1 sovrascrittura nell’evento'
                              : '$overwrites sovrascritture nell’evento',
                          key: const ValueKey('admin_overwrite_warning'),
                        ),
                        TextButton(
                          onPressed: () => _revealEvidence(
                            viewModel,
                            activation,
                            _overwriteTargetKey,
                            () => identical(viewModel.mergePreview, merge),
                          ),
                          child: const Text('Esamina sovrascritture'),
                        ),
                      ],
                      if (external?.stale == true) ...[
                        const Text('È disponibile una fonte aggiornata'),
                        TextButton(
                          onPressed: () => _revealEvidence(
                            viewModel,
                            activation,
                            _sourceTargetKey,
                            () => identical(viewModel.externalEvent, external),
                          ),
                          child: const Text('Esamina fonte aggiornata'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (actions.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    child: ExpansionTile(
                      key: ValueKey(('admin_secondary_actions', expanded)),
                      initiallyExpanded: expanded,
                      title: const Text('Altre azioni'),
                      children: actions
                          .map(
                            (action) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: action,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final activation = viewModel.activation;
          final pickerRequest = viewModel.pickerRequestNonce;
          final status = viewModel.status;
          final previewErrorMessage =
              switch (viewModel.keepCurrentSnapshot.hasFailure
              ? viewModel.keepCurrentSnapshot.data
              : viewModel.previewSnapshot.data) {
                Error(:final AdminContentSubmissionApiException error) =>
                  _moderationErrorMessage(error.code) ?? error.message,
                _ =>
                  'Impossibile completare l’anteprima. '
                      'Verifica i dati e ricarica.',
              };
          final observation = viewModel.recoveryObservation;

          if (viewModel.isEditMode &&
              viewModel.loading &&
              !viewModel.hasLoadedDetail) {
            return const EmptyView.loading(
              text: Text('Caricamento in corso...'),
            );
          }
          // New typing may coexist with a captured Save. Other mutation lanes
          // keep their existing interaction protection.
          final lockEditor =
              !viewModel.isEditable ||
              (viewModel.operationRunning &&
                  !viewModel.saveSnapshot.isRunning) ||
              viewModel.loading;

          final content = CustomScrollView(
            key: const ValueKey<String>('admin_submission_editor_scroll'),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            SentryMask(
                              Text(
                                viewModel.name?.trim().isNotEmpty == true
                                    ? viewModel.name!
                                    : 'Titolo da inserire',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            SentryMask(
                              Text(
                                viewModel.city?.trim().isNotEmpty == true
                                    ? viewModel.city!
                                    : 'Comune da indicare',
                              ),
                            ),
                            Text(
                              '${viewModel.isEvent ? 'Evento' : 'Luogo'} · '
                              '${status?.label ?? 'Nuovo contributo'}',
                            ),
                            if (status == AdminSubmissionStatus.accepted ||
                                status == AdminSubmissionStatus.rejected)
                              const Text('Contributo concluso · sola lettura'),
                            if (viewModel.externalEvent case final external?)
                              Text(
                                external.eventId == null
                                    ? 'Proposta da fonte esterna'
                                    : 'Proposta da fonte esterna · evento '
                                          '#${external.eventId}',
                              ),
                          ],
                        ),
                      ),
                      if (viewModel.recoveryState !=
                              AdminEditorRecoveryState.none ||
                          viewModel.loadSnapshot.hasFailure)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _recoveryMessage(viewModel.recoveryState),
                          ),
                        ),
                      if (observation != null)
                        AdminSubmissionRecoveryPanel(
                          local: observation.localSnapshot,
                          remote: observation.remoteSnapshot,
                          status: observation.detail.status,
                          onAccept:
                              !viewModel.canReconcile(
                                observation,
                                acceptRemote: true,
                              )
                              ? null
                              : () => _request(
                                  viewModel,
                                  () => viewModel.requestReconcile(
                                    observation,
                                    acceptRemote: true,
                                    activation: activation,
                                  ),
                                ),
                          onKeep:
                              !viewModel.canReconcile(
                                observation,
                                acceptRemote: false,
                              )
                              ? null
                              : () => _request(
                                  viewModel,
                                  () => viewModel.requestReconcile(
                                    observation,
                                    acceptRemote: false,
                                    activation: activation,
                                  ),
                                ),
                        ),
                      if (viewModel.pendingRecoveryCheckpoint)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'I campi remoti accettati non sono ancora '
                            'nella bozza locale. '
                            'Salva la bozza locale prima di aprire '
                            'un altro contributo.',
                          ),
                        ),
                      Focus(
                        canRequestFocus: !lockEditor,
                        descendantsAreFocusable: !lockEditor,
                        child: IgnorePointer(
                          ignoring: lockEditor,
                          child: KeyedSubtree(
                            key: _contentTargetKey,
                            child: ContentSubmissionFields(
                              key: ObjectKey(viewModel),
                              formKey: _formKey,
                              hydrationRevision: viewModel.hydrationRevision,
                              eventModeLocked: viewModel.externalEvent != null,
                              category: viewModel.category,
                              city: viewModel.city,
                              name: viewModel.name,
                              description: viewModel.description,
                              descriptionDelta: viewModel.descriptionDelta,
                              isEvent: viewModel.isEvent,
                              allDay: viewModel.allDay,
                              onAllDayChanged: (allDay) => _request(
                                viewModel,
                                () => viewModel.setAllDay(
                                  allDay: allDay,
                                  activation: activation,
                                ),
                              ),
                              startCalendarDate: viewModel.startCalendarDate,
                              startClockTime: viewModel.startClockTime,
                              endCalendarDate: viewModel.endCalendarDate,
                              eventTimeIssue: viewModel.eventTimeIssue,
                              onCategorySelected: (value) => _request(
                                viewModel,
                                () => viewModel.setCategory(
                                  value,
                                  activation: activation,
                                ),
                              ),
                              onCategoryDeleted: () => _request(
                                viewModel,
                                () => viewModel.setCategory(
                                  null,
                                  activation: activation,
                                ),
                              ),
                              onCityChanged: (value) => _request(
                                viewModel,
                                () => viewModel.setCity(
                                  value,
                                  activation: activation,
                                ),
                              ),
                              onNameChanged: (value) => _request(
                                viewModel,
                                () => viewModel.setName(
                                  value,
                                  activation: activation,
                                ),
                              ),
                              onDescriptionChanged:
                                  ({
                                    required description,
                                    required descriptionDelta,
                                  }) => _request(
                                    viewModel,
                                    () => viewModel.setDescription(
                                      activation: activation,
                                      description: description,
                                      descriptionDelta: descriptionDelta,
                                    ),
                                  ),
                              onEventChanged: (enabled) => _request(
                                viewModel,
                                () => viewModel.setEventEnabled(
                                  enabled: enabled,
                                  activation: activation,
                                ),
                              ),
                              onStartDateChanged: (value) => _request(
                                viewModel,
                                () => viewModel.setStartCalendarDate(
                                  value,
                                  activation: activation,
                                ),
                              ),
                              onStartTimeChanged: (value) => _request(
                                viewModel,
                                () => viewModel.setStartClockTime(
                                  value,
                                  activation: activation,
                                ),
                              ),
                              onEndDateChanged: (value) => _request(
                                viewModel,
                                () => viewModel.setEndCalendarDate(
                                  value,
                                  activation: activation,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(key: _temporalTargetKey, height: 8),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const TextSectionDivider('Posizione'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Focus(
                        canRequestFocus: !lockEditor,
                        descendantsAreFocusable: !lockEditor,
                        child: IgnorePointer(
                          ignoring: lockEditor,
                          child: AdminSubmissionLocationEditor(
                            key: ObjectKey(viewModel),
                            latitudeText: viewModel.latitudeText,
                            longitudeText: viewModel.longitudeText,
                            formKey: _locationFormKey,
                            revealCoordinatesRevision:
                                _revealCoordinatesRevision,
                            onLatitudeTextChanged: (value) => _request(
                              viewModel,
                              () => viewModel.setLatitudeText(
                                value,
                                activation: activation,
                              ),
                            ),
                            onLongitudeTextChanged: (value) => _request(
                              viewModel,
                              () => viewModel.setLongitudeText(
                                value,
                                activation: activation,
                              ),
                            ),
                            onMapCoordinatesSelected: (latitude, longitude) =>
                                _request(
                                  viewModel,
                                  () => viewModel.setCoordinates(
                                    latitude,
                                    longitude,
                                    activation: activation,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!viewModel.isEditMode ||
                  viewModel.hasLoadedDetail ||
                  viewModel.stagedAssets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const TextSectionDivider('Foto'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: <Widget>[
                            Text(
                              '${viewModel.imageCount} / '
                              '$kMaximumSubmissionAssetCount',
                            ),
                            if (viewModel.stagedAssets.any(
                              viewModel.isStagedAssociationUnavailable,
                            ))
                              const Text(
                                'La presenza remota di una foto confermata '
                                'non è verificata. '
                                'La copia locale è conservata: puoi rimuoverla '
                                'dalla bozza '
                                'o verificare di nuovo lo stato remoto.',
                              ),
                            if (viewModel.stagedAssets.any(
                              (asset) => asset.progressInvalid,
                            ))
                              const Text(
                                'La conferma di una foto non è leggibile. '
                                'I file locali sono conservati; '
                                'la ripresa è sospesa.',
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                ...viewModel.stagedAssets.map(
                                  (asset) => ContentSubmissionAssetListItem(
                                    key: ValueKey(
                                      'admin_staged_${asset.digest}',
                                    ),
                                    image: FutureBuilder<Result<File>>(
                                      future: viewModel.stagedAssetFile(asset),
                                      builder: (context, snapshot) =>
                                          switch (snapshot.data) {
                                            Success<File>(:final value) =>
                                              Image.file(
                                                value,
                                                width:
                                                    contentSubmissionAssetSize
                                                        .width,
                                                height:
                                                    contentSubmissionAssetSize
                                                        .height,
                                                fit: BoxFit.cover,
                                              ),
                                            _ => const SizedBox(
                                              width: 80,
                                              height: 80,
                                              child: Icon(Icons.image),
                                            ),
                                          },
                                    ),
                                    removeButtonSize: 48,
                                    showRemoveIcon: viewModel.canCheckpoint,
                                    onRemove: viewModel.operationRunning
                                        ? null
                                        : () => viewModel
                                              .requestRemoveStagedAsset(
                                                asset,
                                                activation: activation,
                                              ),
                                  ),
                                ),
                                ...viewModel.assets.map((asset) {
                                  return ContentSubmissionAssetListItem(
                                    key: ValueKey<String>(
                                      'admin_submission_asset_${asset.id}',
                                    ),
                                    image: AppNetworkImage(
                                      url: asset.url,
                                      imageWidth: asset.width,
                                      imageHeight: asset.height,
                                      width: contentSubmissionAssetSize.width,
                                      height: contentSubmissionAssetSize.height,
                                    ),
                                    removeButtonSize: 48,
                                    showRemoveIcon:
                                        status == AdminSubmissionStatus.pending,
                                    onRemove: !viewModel.canRequestDeleteAsset
                                        ? null
                                        : () => unawaited(
                                            _confirmAssetDeletion(
                                              viewModel,
                                              asset.id,
                                            ),
                                          ),
                                  );
                                }),
                                if (((!viewModel.isEditMode ||
                                            status ==
                                                AdminSubmissionStatus
                                                    .pending) &&
                                        viewModel.imageCount <
                                            kMaximumSubmissionAssetCount) &&
                                    viewModel.canRequestAddAsset)
                                  ContentSubmissionAddAssetButton(
                                    key: const ValueKey<String>(
                                      'admin_submission_add_asset',
                                    ),
                                    onPressed: !viewModel.canRequestAddAsset
                                        ? null
                                        : () {
                                            _unfocus();
                                            _request(
                                              viewModel,
                                              () => viewModel.requestAddAsset(
                                                activation: activation,
                                              ),
                                            );
                                          },
                                  ),
                                if (viewModel.pickerWaiting)
                                  TextButton(
                                    onPressed: () {
                                      if (viewModel.isActivationCurrent(
                                        activation,
                                      )) {
                                        if (pickerRequest != null) {
                                          viewModel.abandonPicker(
                                            requestNonce: pickerRequest,
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Interrompi selezione'),
                                  ),
                                if (viewModel.operationRunning)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CustomCircularProgressIndicator(
                                      size: 36,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (viewModel.isEditMode && status != null)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextSectionDivider(
                        'Verifica e confronto',
                        key: _verificationTargetKey,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: <Widget>[
                            if (viewModel.externalEvent
                                case final external?) ...[
                              if (external.stale)
                                const Text(
                                  'La proposta è precedente alla versione '
                                  'corrente della fonte.',
                                ),
                              Text(
                                'Versione corrente della fonte',
                                key: _sourceTargetKey,
                              ),
                              if (external.currentSnapshot == null)
                                const Text(
                                  'Dettaglio della fonte non disponibile.',
                                ),
                              if (external.currentSnapshot
                                  case final source?) ...[
                                for (final entry in source.entries)
                                  SentryMask(
                                    SelectableText(
                                      '${switch (entry.key) {
                                        'name' => 'Nome',
                                        'category' => 'Categoria',
                                        'description' => 'Descrizione',
                                        'city' => 'Città',
                                        'latitude' => 'Latitudine',
                                        'longitude' => 'Longitudine',
                                        'all_day' => 'Tutto il giorno',
                                        'start_date' => 'Inizio',
                                        'end_date' => 'Fine',
                                        _ => entry.key,
                                      }}: ${entry.value ?? "Non disponibile"}',
                                    ),
                                  ),
                              ],
                              if (external.stale &&
                                  status == AdminSubmissionStatus.pending)
                                CheckboxListTile(
                                  key: const ValueKey(
                                    'admin_acknowledge_current_source',
                                  ),
                                  subtitle: const Text(
                                    'La risoluzione della proposta '
                                    'non considera '
                                    'automaticamente valutate '
                                    'le revisioni più recenti.',
                                  ),
                                  title: const Text(
                                    'Considera valutata anche la versione '
                                    'corrente della fonte',
                                  ),
                                  value: viewModel.acknowledgeCurrentSource,
                                  onChanged: viewModel.operationRunning
                                      ? null
                                      : (value) {
                                          if (!identical(
                                            viewModel.externalEvent,
                                            external,
                                          )) {
                                            return;
                                          }
                                          _request(
                                            viewModel,
                                            () => viewModel
                                                .setAcknowledgeCurrentSource(
                                                  selected: value ?? false,
                                                  activation: activation,
                                                ),
                                          );
                                        },
                                ),
                            ],
                            if (status == AdminSubmissionStatus.pending) ...[
                              if (viewModel.startDate != null) ...[
                                SentryMask(
                                  KeyedSubtree(
                                    key: ObjectKey(viewModel),
                                    child: TextFormField(
                                      key: const ValueKey('admin_event_search'),
                                      decoration: const InputDecoration(
                                        labelText: 'Cerca evento per nome',
                                      ),
                                      initialValue: viewModel.candidateSearch,
                                      onChanged: (value) => _request(
                                        viewModel,
                                        () => viewModel.setCandidateSearch(
                                          value,
                                          activation: activation,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: !viewModel.canRequestFindCandidates
                                      ? null
                                      : () => _request(
                                          viewModel,
                                          () => viewModel.requestFindCandidates(
                                            activation: activation,
                                          ),
                                        ),
                                  child: const Text('Cerca eventi'),
                                ),
                                if (viewModel.findCandidatesSnapshot.hasFailure)
                                  const Text(
                                    'Impossibile cercare gli eventi. Riprova.',
                                  ),
                                if (viewModel.candidates
                                    case final matches?) ...[
                                  for (final warning in matches.pendingWarnings)
                                    SentryMask(
                                      Text(
                                        'Altro contributo in attesa: '
                                        '${warning.name} (#${warning.id}). '
                                        'Questo avviso non blocca '
                                        'la moderazione.',
                                      ),
                                    ),
                                  for (final candidate in matches.events)
                                    ListTile(
                                      key: ValueKey(
                                        'admin_event_candidate_${candidate.id}',
                                      ),
                                      title: Text(candidate.name),
                                      subtitle: Text(
                                        candidate.city == null
                                            ? 'Città non disponibile '
                                                  '· #${candidate.id}'
                                            : '${candidate.city} '
                                                  '· #${candidate.id}',
                                      ),
                                      selected:
                                          viewModel.targetEventId ==
                                          candidate.id,
                                      onTap:
                                          viewModel.operationRunning ||
                                              viewModel.loading
                                          ? null
                                          : () => _request(
                                              viewModel,
                                              () => viewModel.selectTargetEvent(
                                                candidate.id,
                                                activation: activation,
                                              ),
                                            ),
                                    ),
                                ],
                                if (viewModel.targetEventId case final target?)
                                  Text('Evento selezionato: #$target'),
                                TextFormField(
                                  key: const ValueKey('admin_event_target'),
                                  controller: _eventTargetController,
                                  decoration: const InputDecoration(
                                    labelText: 'ID evento esistente',
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled:
                                      !viewModel.operationRunning &&
                                      !viewModel.loading,
                                  onChanged: (value) => _request(
                                    viewModel,
                                    () => viewModel.selectTargetEvent(
                                      int.tryParse(value),
                                      activation: activation,
                                    ),
                                  ),
                                ),
                                if (viewModel.isExternalUpdate) ...[
                                  if (viewModel.previewSnapshot.hasFailure ||
                                      viewModel.keepCurrentSnapshot.hasFailure)
                                    SentryMask(Text(previewErrorMessage)),
                                  if (viewModel.mergePreview case final merge?)
                                    for (final group in _orderedGroups(
                                      merge.groups,
                                    ))
                                      Card(
                                        key:
                                            identical(
                                              group,
                                              merge.groups
                                                  .where((g) => g.overwrite)
                                                  .firstOrNull,
                                            )
                                            ? _overwriteTargetKey
                                            : ObjectKey(group),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _mergeLabel(group.name),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                              Text(
                                                group.apply
                                                    ? 'Da applicare'
                                                    : 'Resta invariato',
                                              ),
                                              if (group.overwrite)
                                                const Text(
                                                  'Sovrascrive modifiche del '
                                                  'moderatore '
                                                  'nell’evento attuale',
                                                ),

                                              SentryMask(
                                                Text(
                                                  'Proposta: '
                                                  '${group.moderated}',
                                                ),
                                              ),
                                              SelectableText(
                                                'Attuale: ${group.current}',
                                              ),
                                              ExpansionTile(
                                                title: const Text(
                                                  'Base e fonte complete',
                                                ),
                                                children: [
                                                  SentryMask(
                                                    SelectableText(
                                                      'Base: ${group.base}',
                                                    ),
                                                  ),
                                                  SentryMask(
                                                    SelectableText(
                                                      'Fonte: ${group.source}',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              TextButton(
                                                onPressed:
                                                    !viewModel
                                                        .canRequestKeepCurrent
                                                    ? null
                                                    : () => _request(
                                                        viewModel,
                                                        () => viewModel
                                                            .requestKeepCurrent(
                                                              group,
                                                              activation:
                                                                  activation,
                                                            ),
                                                      ),
                                                child: const Text(
                                                  'Mantieni valore attuale',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ],
                              ],
                            ] else ...[
                              Text(status.label),
                              if (viewModel.promotion case final promotion?
                                  when status == AdminSubmissionStatus.accepted)
                                Text(_publishedAs(promotion)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (viewModel.isEditMode)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ExpansionTile(
                              title: const Text('Autore e dettagli tecnici'),
                              children: [
                                if (viewModel.contributorName case final name?)
                                  SentryMask(Text(name)),
                                if (viewModel.contributorEmail
                                    case final email?)
                                  SentryMask(Text(email)),
                                SentryMask(
                                  Text('Contributo #${viewModel.submissionId}'),
                                ),
                                if (viewModel.createdAt case final created?)
                                  SentryMask(Text('Creato il $created')),
                                if (viewModel.modifiedAt case final modified?)
                                  SentryMask(Text('Modificato il $modified')),
                                if (viewModel.externalEvent case final source?)
                                  SentryMask(
                                    SelectableText(
                                      'Record fonte #${source.recordId} · '
                                      'versione ${source.snapshotVersion}\n'
                                      'Hash proposta: ${source.snapshotHash}\n'
                                      'Hash corrente: '
                                      '${source.currentHash ?? 'Assente'}'
                                      '\n'
                                      'Proposta originale: ${source.snapshot}',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (viewModel.contributorName case final name?)
                if (viewModel.contributorEmail case final email?)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Creato come $name · $email'),
                    ),
                  ),
            ],
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final expanded =
                  constraints.maxWidth >= 840 &&
                  constraints.maxWidth >= (520 + 320) * scale + 24;
              return Column(
                children: [
                  AppBar(
                    leading: CustomBackButton(onPressed: widget.onBack),
                    title: Text(
                      viewModel.isEditMode
                          ? 'Revisiona contributo'
                          : 'Nuovo contributo',
                    ),
                  ),
                  Expanded(
                    child: Flex(
                      direction: expanded ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: content,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: expanded ? 320 * scale : null,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: expanded
                                  ? double.infinity
                                  : constraints.maxHeight * .5,
                            ),
                            child: _decisionArea(
                              viewModel,
                              activation,
                              expanded: expanded,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
