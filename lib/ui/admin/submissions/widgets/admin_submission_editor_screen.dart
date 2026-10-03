import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_location_editor.dart';
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
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';

/// Form screen for creating and editing a moderation submission.
class AdminSubmissionEditorScreen extends StatefulWidget {
  /// Creates an editor backed by route-scoped [viewModel] state.
  const AdminSubmissionEditorScreen({required this.viewModel, super.key});

  /// Editor state and commands for this route visit.
  final AdminSubmissionEditorViewModel viewModel;

  @override
  State<AdminSubmissionEditorScreen> createState() =>
      _AdminSubmissionEditorScreenState();
}

class _AdminSubmissionEditorScreenState
    extends State<AdminSubmissionEditorScreen> {
  String _eventSearch = '';
  final _eventTargetController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();
  var _statusDialogOpen = false;
  var _saveCompletedWhileStatusDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _syncEventTarget();
    widget.viewModel.addListener(_syncEventTarget);
    widget.viewModel.save.addListener(_handleSaveCompleted);
    widget.viewModel.reject.addListener(_handleRejectCompleted);
    widget.viewModel.promote.addListener(_handlePromoteCompleted);
    widget.viewModel.link.addListener(_handleLinkCompleted);
    widget.viewModel.apply.addListener(_handleApplyCompleted);
    widget.viewModel.addAsset.addListener(_handleAddAssetCompleted);
    widget.viewModel.deleteAsset.addListener(_handleDeleteAssetCompleted);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_syncEventTarget);
    _eventTargetController.dispose();
    widget.viewModel.save.removeListener(_handleSaveCompleted);
    widget.viewModel.reject.removeListener(_handleRejectCompleted);
    widget.viewModel.promote.removeListener(_handlePromoteCompleted);
    widget.viewModel.link.removeListener(_handleLinkCompleted);
    widget.viewModel.apply.removeListener(_handleApplyCompleted);
    widget.viewModel.addAsset.removeListener(_handleAddAssetCompleted);
    widget.viewModel.deleteAsset.removeListener(_handleDeleteAssetCompleted);
    super.dispose();
  }

  void _syncEventTarget() {
    if (!mounted) return;
    final target = widget.viewModel.targetEventId;
    // Preserve raw manual input when it already represents the selected ID.
    if (int.tryParse(_eventTargetController.text) == target) return;
    final text = target?.toString() ?? '';
    _eventTargetController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleLinkCompleted() {
    if (!mounted) return;
    _handleResolutionCompleted(widget.viewModel.link);
  }

  void _handleApplyCompleted() {
    if (!mounted) return;
    _handleResolutionCompleted(widget.viewModel.apply);
  }

  void _handleResolutionCompleted(Command<AdminEventResolution> command) {
    if (!mounted || command.running || command.idle) return;
    if (command.completed) {
      context.pop(true);
    } else if (command.error) {
      _showModerationError(command.result);
    }
  }

  void _showModerationError(Result<dynamic>? result) {
    if (!mounted) return;
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

  void _handleSaveCompleted() {
    if (!mounted) return;

    final save = widget.viewModel.save;
    if (save.completed) {
      if (_statusDialogOpen) {
        _saveCompletedWhileStatusDialogOpen = true;
        return;
      }
      context.pop(true);
    } else if (save.error) {
      final result = save.result;
      if (result
          case Error<void>(:final AdminContentSubmissionApiException error)
          when error.statusCode == 422 &&
              error.code == 'ADMIN_PROFILE_INCOMPLETE') {
        showSnackBar(
          context: context,
          textContent:
              "Il profilo amministratore richiede un nome e un'email validi.",
          type: SnackBarType.error,
        );
      } else {
        _showModerationError(save.result);
      }
    }
  }

  void _handleRejectCompleted() {
    if (!mounted) return;

    final reject = widget.viewModel.reject;
    if (reject.completed) {
      // Success pops through the route result so the dashboard reloads.
      context.pop(true);
    } else if (reject.error) {
      final result = reject.result;
      if (result case Error<void>(
        :final AdminContentSubmissionApiException error,
      ) when error.code == 'INVALID_STATUS_TRANSITION') {
        showSnackBar(
          context: context,
          textContent:
              'Il contributo non è più in attesa. Ricarica la schermata.',
          type: SnackBarType.error,
        );
      } else {
        _showModerationError(reject.result);
      }
    }
  }

  void _handlePromoteCompleted() {
    if (!mounted) return;

    final promote = widget.viewModel.promote;
    if (promote.completed) {
      // Success pops through the route result so the dashboard refreshes.
      context.pop(true);
    } else if (promote.error) {
      final result = promote.result;
      final String? message;
      if (result case Error<AdminSubmissionPromotion>(
        :final AdminContentSubmissionApiException error,
      )) {
        message = _moderationErrorMessage(error.code);
      } else {
        message = null;
      }
      if (message != null) {
        showSnackBar(
          context: context,
          textContent: message,
          type: SnackBarType.error,
        );
      } else {
        showSnackBarGenericError(context: context);
      }
    }
  }

  /// Maps known promotion failure codes to actionable Italian copy; unknown
  /// codes fall back to the generic snackbar.
  String? _moderationErrorMessage(String? code) => switch (code
      ?.toUpperCase()) {
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
      'Seleziona una categoria e salva prima di pubblicare.',
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

  void _handleAddAssetCompleted() {
    if (!mounted) return;
    if (widget.viewModel.addAsset.error) {
      showSnackBarGenericError(context: context);
    }
  }

  void _handleDeleteAssetCompleted() {
    if (!mounted) return;
    if (widget.viewModel.deleteAsset.error) {
      showSnackBarGenericError(context: context);
    }
  }

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

  Future<void> _confirmPublish(AdminPromotionTarget target) async {
    if (!mounted) return;

    final viewModel = widget.viewModel;
    if (viewModel.operationRunning) return;

    _unfocus();
    _statusDialogOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Conferma'),
              ),
            ],
          );
        },
      );
      final saveCompleted = _saveCompletedWhileStatusDialogOpen;
      if (!mounted) return;
      if (saveCompleted) {
        context.pop(true);
        return;
      }
      if (confirmed != true || viewModel.operationRunning) return;

      unawaited(viewModel.promote.execute(target));
    } finally {
      _statusDialogOpen = false;
      _saveCompletedWhileStatusDialogOpen = false;
    }
  }

  Future<void> _confirmReject() async {
    if (!mounted) return;

    final viewModel = widget.viewModel;
    if (viewModel.operationRunning) return;

    var ignoreSource = viewModel.ignoreSource;
    _unfocus();
    _statusDialogOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Confermi di voler rifiutare questo contributo?'),
                  if (viewModel.externalEvent != null) ...[
                    const Text(
                      'Rifiutare una revisione considera quella revisione '
                      'sorgente esaminata e scartata. Le modifiche ancora '
                      'presenti in revisioni future non vengono riproposte '
                      'finché il provider non modifica nuovamente il relativo '
                      'gruppo.',
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'Ignora anche le revisioni future della fonte',
                      ),
                      subtitle: const Text(
                        'Le revisioni future saranno soppresse finché non '
                        'riattivi la fonte da Fonti ignorate.',
                      ),
                      value: ignoreSource,
                      onChanged: (value) =>
                          setDialogState(() => ignoreSource = value ?? false),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Conferma'),
                ),
              ],
            ),
          );
        },
      );
      final saveCompleted = _saveCompletedWhileStatusDialogOpen;
      if (!mounted) return;
      if (saveCompleted) {
        context.pop(true);
        return;
      }
      if (confirmed != true || viewModel.operationRunning) return;

      viewModel.setIgnoreSource(ignored: ignoreSource);
      unawaited(viewModel.reject.execute());
    } finally {
      _statusDialogOpen = false;
      _saveCompletedWhileStatusDialogOpen = false;
    }
  }

  Future<void> _confirmAssetDeletion(int assetId) async {
    if (!mounted) return;

    final viewModel = widget.viewModel;
    if (viewModel.operationRunning) return;

    _unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: const Text('Rimuovere questa foto dal suggerimento?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (confirmed != true || viewModel.operationRunning) return;

    unawaited(viewModel.deleteAsset.execute(assetId));
  }

  void _save() {
    final contentOk = _formKey.currentState?.validate() ?? false;
    final locationOk = _locationFormKey.currentState?.validate() ?? false;
    final eventTimeOk = widget.viewModel.validateEventTimeForSave();
    if (contentOk && locationOk && eventTimeOk) {
      _unfocus();
      unawaited(widget.viewModel.save.execute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          viewModel,
          viewModel.load,
          viewModel.save,
          viewModel.promote,
          viewModel.reject,
          viewModel.link,
          viewModel.apply,
          viewModel.preview,
          viewModel.keepCurrent,
          viewModel.findCandidates,
          viewModel.addAsset,
          viewModel.deleteAsset,
        ]),
        builder: (context, _) {
          final status = viewModel.status;

          if (viewModel.isEditMode &&
              viewModel.loading &&
              !viewModel.hasLoadedDetail) {
            return const EmptyView.loading(
              text: Text('Caricamento in corso...'),
            );
          }
          if (viewModel.isEditMode &&
              viewModel.load.error &&
              !viewModel.hasLoadedDetail) {
            return EmptyView.error(
              text: const Text('Impossibile caricare il contributo'),
              action: FilledButton(
                onPressed: viewModel.load.execute,
                child: const Text('Riprova'),
              ),
            );
          }

          // Draft interaction is locked both for final read-only states and
          // while any mutation is running, so edits made after the request
          // snapshot cannot be silently lost when success pops the route.
          final lockEditor =
              !viewModel.isEditable || viewModel.operationRunning;

          return CustomScrollView(
            key: const ValueKey<String>('admin_submission_editor_scroll'),
            slivers: <Widget>[
              SliverAppBar(
                leading: const CustomBackButton(),
                title: Text(
                  viewModel.isEditMode
                      ? 'Modifica contributo'
                      : 'Nuovo contributo',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(
                  children: <Widget>[
                    Focus(
                      canRequestFocus: !lockEditor,
                      descendantsAreFocusable: !lockEditor,
                      child: IgnorePointer(
                        ignoring: lockEditor,
                        child: Opacity(
                          // De-emphasis marks only FINAL read-only states;
                          // transient busy states stay fully visible.
                          opacity: viewModel.isEditable ? 1.0 : 0.55,
                          child: ContentSubmissionFields(
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
                            onAllDayChanged: (allDay) =>
                                viewModel.setAllDay(allDay: allDay),
                            startCalendarDate: viewModel.startCalendarDate,
                            startClockTime: viewModel.startClockTime,
                            endCalendarDate: viewModel.endCalendarDate,
                            eventTimeIssue: viewModel.eventTimeIssue,
                            onCategorySelected: viewModel.setCategory,
                            onCategoryDeleted: () =>
                                viewModel.setCategory(null),
                            onCityChanged: viewModel.setCity,
                            onNameChanged: viewModel.setName,
                            onDescriptionChanged: viewModel.setDescription,
                            onEventChanged: viewModel.setEventEnabled,
                            onStartDateChanged: viewModel.setStartCalendarDate,
                            onStartTimeChanged: viewModel.setStartClockTime,
                            onEndDateChanged: viewModel.setEndCalendarDate,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverList.list(
                children: <Widget>[
                  const TextSectionDivider('Posizione'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Focus(
                      canRequestFocus: !lockEditor,
                      descendantsAreFocusable: !lockEditor,
                      child: IgnorePointer(
                        ignoring: lockEditor,
                        child: Opacity(
                          opacity: viewModel.isEditable ? 1.0 : 0.55,
                          child: AdminSubmissionLocationEditor(
                            latitudeText: viewModel.latitudeText,
                            longitudeText: viewModel.longitudeText,
                            formKey: _locationFormKey,
                            onLatitudeTextChanged: viewModel.setLatitudeText,
                            onLongitudeTextChanged: viewModel.setLongitudeText,
                            onMapCoordinatesSelected: viewModel.setCoordinates,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (viewModel.isEditMode && viewModel.hasLoadedDetail)
                SliverList.list(
                  children: <Widget>[
                    const TextSectionDivider('Foto'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: <Widget>[
                          Text(
                            '${viewModel.assets.length} / '
                            '$kMaximumSubmissionAssetCount',
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
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
                                  showRemoveIcon:
                                      status == AdminSubmissionStatus.pending,
                                  onRemove: viewModel.operationRunning
                                      ? null
                                      : () => unawaited(
                                          _confirmAssetDeletion(asset.id),
                                        ),
                                );
                              }),
                              if ((status == AdminSubmissionStatus.pending &&
                                      viewModel.assets.length <
                                          kMaximumSubmissionAssetCount) &&
                                  !viewModel.operationRunning)
                                ContentSubmissionAddAssetButton(
                                  key: const ValueKey<String>(
                                    'admin_submission_add_asset',
                                  ),
                                  onPressed: viewModel.operationRunning
                                      ? null
                                      : () {
                                          _unfocus();
                                          unawaited(
                                            viewModel.addAsset.execute(),
                                          );
                                        },
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
              if (viewModel.isEditMode)
                SliverList.list(
                  children: <Widget>[
                    const TextSectionDivider('Proposto da'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (viewModel.contributorName case final name?)
                            Text(name),
                          if (viewModel.contributorEmail case final email?)
                            Text(email),
                        ],
                      ),
                    ),
                  ],
                )
              else if (viewModel.contributorName case final name?)
                if (viewModel.contributorEmail case final email?)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Creato come $name · $email'),
                    ),
                  ),
              if (viewModel.isEditMode && status != null)
                SliverList.list(
                  children: <Widget>[
                    const TextSectionDivider('Stato'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: <Widget>[
                          if (viewModel.externalEvent case final external?) ...[
                            if (external.stale)
                              const Text(
                                'La proposta è precedente alla versione '
                                'corrente della fonte.',
                              ),
                            if (external.currentSnapshot
                                case final source?) ...[
                              const Text('Versione corrente della fonte'),
                              for (final entry in source.entries.where(
                                (entry) => entry.key != 'description_delta',
                              ))
                                Text(
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
                            ],
                            if (external.stale &&
                                status == AdminSubmissionStatus.pending)
                              CheckboxListTile(
                                key: const ValueKey(
                                  'admin_acknowledge_current_source',
                                ),
                                title: const Text(
                                  'Considera valutata anche la versione '
                                  'corrente della fonte',
                                ),
                                value: viewModel.acknowledgeCurrentSource,
                                onChanged: viewModel.operationRunning
                                    ? null
                                    : (value) =>
                                          viewModel.setAcknowledgeCurrentSource(
                                            selected: value ?? false,
                                          ),
                              ),
                          ],
                          if (status == AdminSubmissionStatus.pending) ...[
                            if (viewModel.startDate != null) ...[
                              TextFormField(
                                key: const ValueKey('admin_event_search'),
                                decoration: const InputDecoration(
                                  labelText: 'Cerca evento per nome',
                                ),
                                onChanged: (value) => _eventSearch = value,
                              ),
                              TextButton(
                                onPressed: viewModel.findCandidates.running
                                    ? null
                                    : () => unawaited(
                                        viewModel.findCandidates.execute(
                                          _eventSearch,
                                        ),
                                      ),
                                child: const Text('Cerca eventi'),
                              ),
                              if (viewModel.findCandidates.error)
                                const Text(
                                  'Impossibile cercare gli eventi. Riprova.',
                                ),
                              if (viewModel.candidates case final matches?) ...[
                                for (final warning in matches.pendingWarnings)
                                  Text(
                                    'Altro contributo in attesa: '
                                    '${warning.name} (#${warning.id}). '
                                    'Questo avviso non blocca '
                                    'la moderazione.',
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
                                        viewModel.targetEventId == candidate.id,
                                    onTap: viewModel.operationRunning
                                        ? null
                                        : () => viewModel.selectTargetEvent(
                                            candidate.id,
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
                                enabled: !viewModel.operationRunning,
                                onChanged: (value) => viewModel
                                    .selectTargetEvent(int.tryParse(value)),
                              ),
                              FilledButton.tonal(
                                onPressed:
                                    viewModel.isDirty ||
                                        viewModel.operationRunning ||
                                        viewModel.targetEventId == null
                                    ? null
                                    : () => unawaited(
                                        viewModel.link.execute(
                                          viewModel.targetEventId!,
                                        ),
                                      ),
                                child: const Text('Collega a evento'),
                              ),
                              if (viewModel.isExternalUpdate) ...[
                                TextButton(
                                  onPressed:
                                      viewModel.isDirty ||
                                          viewModel.operationRunning
                                      ? null
                                      : viewModel.preview.execute,
                                  child: const Text('Anteprima aggiornamento'),
                                ),
                                if (viewModel.preview.error ||
                                    viewModel.keepCurrent.error)
                                  Text(switch (viewModel.keepCurrent.error
                                      ? viewModel.keepCurrent.result
                                      : viewModel.preview.result) {
                                    Error(
                                      :final AdminContentSubmissionApiException
                                      error,
                                    ) =>
                                      _moderationErrorMessage(error.code) ??
                                          error.message,
                                    _ =>
                                      'Impossibile completare l’anteprima. '
                                          'Verifica i dati e ricarica.',
                                  }),
                                if (viewModel.mergePreview case final merge?)
                                  for (final group in merge.groups)
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.apply
                                                  ? '${group.name}: applicato'
                                                  : '${group.name}: '
                                                        'non applicato',
                                            ),
                                            if (group.overwrite)
                                              const Text(
                                                'Sovrascrive modifiche del '
                                                'moderatore '
                                                'nell’evento attuale',
                                              ),
                                            Text('Base: ${group.base}'),
                                            Text('Fonte: ${group.source}'),
                                            Text(
                                              'Proposta: ${group.moderated}',
                                            ),
                                            Text('Attuale: ${group.current}'),
                                            TextButton(
                                              onPressed:
                                                  viewModel.operationRunning
                                                  ? null
                                                  : () => unawaited(
                                                      viewModel.keepCurrent
                                                          .execute(group),
                                                    ),
                                              child: const Text(
                                                'Mantieni valore attuale',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                if (viewModel.mergePreview != null)
                                  FilledButton(
                                    onPressed: viewModel.operationRunning
                                        ? null
                                        : viewModel.apply.execute,
                                    child: const Text('Applica aggiornamento'),
                                  ),
                              ],
                            ],
                            if (viewModel.isDirty)
                              const Text(
                                'Salva le modifiche prima di pubblicare o '
                                'rifiutare.',
                              )
                            else if (!viewModel.hasPublishableCategory)
                              const Text(
                                'Seleziona una categoria e salva prima di '
                                'pubblicare.',
                              ),
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                // One CTA chosen by the persisted draft: an
                                // end-date-only historical row still counts
                                // as an event and surfaces the start-date
                                // readiness error on publication.
                                if (!viewModel.isExternalUpdate)
                                  FilledButton.tonal(
                                    onPressed:
                                        viewModel.isDirty ||
                                            viewModel.operationRunning ||
                                            !viewModel.hasPublishableCategory
                                        ? null
                                        : () => unawaited(
                                            _confirmPublish(
                                              viewModel.isEvent
                                                  ? AdminPromotionTarget.event
                                                  : AdminPromotionTarget.place,
                                            ),
                                          ),
                                    child: Text(
                                      viewModel.isEvent
                                          ? 'Pubblica come evento'
                                          : 'Pubblica come luogo',
                                    ),
                                  ),
                                FilledButton.tonal(
                                  onPressed:
                                      viewModel.isDirty ||
                                          viewModel.operationRunning
                                      ? null
                                      : () => unawaited(_confirmReject()),
                                  child: const Text('Rifiuta'),
                                ),
                              ],
                            ),
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
              // Non-pending submissions are read-only: their Save control is
              // hidden entirely instead of merely disabled.
              if (!viewModel.isEditMode ||
                  status == AdminSubmissionStatus.pending)
                SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: viewModel.operationRunning ? null : _save,
                        icon: const Icon(Symbols.save),
                        label: Text(
                          viewModel.isEditMode
                              ? 'Salva modifiche'
                              : 'Crea contributo',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
