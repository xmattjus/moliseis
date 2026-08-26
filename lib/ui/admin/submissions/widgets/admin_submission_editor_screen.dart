import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_location_editor.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';

/// Form screen for creating and editing a moderation submission.
class AdminSubmissionEditorScreen extends StatefulWidget {
  /// Creates an editor backed by route-scoped [viewModel] state.
  const AdminSubmissionEditorScreen({
    required this.viewModel,
    super.key,
  });

  /// Editor state and commands for this route visit.
  final AdminSubmissionEditorViewModel viewModel;

  @override
  State<AdminSubmissionEditorScreen> createState() =>
      _AdminSubmissionEditorScreenState();
}

class _AdminSubmissionEditorScreenState
    extends State<AdminSubmissionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();
  var _statusDialogOpen = false;
  var _saveCompletedWhileStatusDialogOpen = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.save.addListener(_handleSaveCompleted);
    widget.viewModel.reject.addListener(_handleRejectCompleted);
    widget.viewModel.promote.addListener(_handlePromoteCompleted);
    widget.viewModel.addAsset.addListener(_handleAddAssetCompleted);
    widget.viewModel.deleteAsset.addListener(_handleDeleteAssetCompleted);
  }

  @override
  void dispose() {
    widget.viewModel.save.removeListener(_handleSaveCompleted);
    widget.viewModel.reject.removeListener(_handleRejectCompleted);
    widget.viewModel.promote.removeListener(_handlePromoteCompleted);
    widget.viewModel.addAsset.removeListener(_handleAddAssetCompleted);
    widget.viewModel.deleteAsset.removeListener(_handleDeleteAssetCompleted);
    super.dispose();
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
        showSnackBarGenericError(context: context);
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
        showSnackBarGenericError(context: context);
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
        message = _promotionErrorMessage(error.code);
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
  String? _promotionErrorMessage(String? code) => switch (code) {
    'PROMOTION_COORDINATES_REQUIRED' || 'PROMOTION_INVALID_COORDINATES' =>
      'Imposta coordinate valide e salva prima di pubblicare.',
    'PROMOTION_CITY_NOT_FOUND' =>
      'La città non corrisponde a una località disponibile. '
          'Correggila e salva.',
    'PROMOTION_PLACE_HAS_EVENT_DATES' =>
      "Rimuovi le date dell'evento e salva prima di pubblicare "
          'come luogo.',
    'PROMOTION_START_DATE_REQUIRED' =>
      'Imposta una data di inizio e salva prima di pubblicare '
          "l'evento.",
    'PROMOTION_INVALID_DATE_RANGE' =>
      "Correggi le date dell'evento e salva prima di pubblicare.",
    'PROMOTION_INVALID_NAME' =>
      'Inserisci un nome valido e salva prima di pubblicare.',
    'PROMOTION_INVALID_ASSET' =>
      'Una foto associata non è valida e impedisce la pubblicazione.',
    'PROMOTION_TARGET_CONFLICT' =>
      'Il contributo è già stato pubblicato con un tipo diverso.',
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

    _unfocus();
    _statusDialogOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: const Text(
              'Confermi di voler rifiutare questo contributo?',
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
    if (contentOk && locationOk) {
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
                            category: viewModel.category,
                            city: viewModel.city,
                            name: viewModel.name,
                            description: viewModel.description,
                            descriptionDelta: viewModel.descriptionDelta,
                            startDate: viewModel.startDate,
                            endDate: viewModel.endDate,
                            onCategorySelected: viewModel.setCategory,
                            onCategoryDeleted: () =>
                                viewModel.setCategory(null),
                            onCityChanged: viewModel.setCity,
                            onNameChanged: viewModel.setName,
                            onDescriptionChanged: viewModel.setDescription,
                            onStartDateChanged: viewModel.setStartDate,
                            onStartTimeChanged: viewModel.setStartTime,
                            onEndDateChanged: viewModel.setEndDate,
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
                              ...viewModel.assets.map(
                                (asset) => Stack(
                                  key: ValueKey<String>(
                                    'admin_submission_asset_${asset.id}',
                                  ),
                                  alignment: Alignment.topRight,
                                  children: <Widget>[
                                    AppNetworkImage(
                                      url: asset.url,
                                      imageWidth: asset.width,
                                      imageHeight: asset.height,
                                      width: 100,
                                      height: 100,
                                    ),
                                    if (status == AdminSubmissionStatus.pending)
                                      IconButton(
                                        key: ValueKey<String>(
                                          'admin_submission_delete_asset_'
                                          '${asset.id}',
                                        ),
                                        onPressed: viewModel.operationRunning
                                            ? null
                                            : () => unawaited(
                                                _confirmAssetDeletion(asset.id),
                                              ),
                                        tooltip: 'Rimuovi foto',
                                        icon: const Icon(Symbols.delete),
                                      ),
                                  ],
                                ),
                              ),
                              if (status == AdminSubmissionStatus.pending &&
                                  viewModel.assets.length <
                                      kMaximumSubmissionAssetCount)
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: OutlinedButton(
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
                                    child: viewModel.addAsset.running
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(),
                                          )
                                        : const Icon(Symbols.add_a_photo),
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
                          if (status == AdminSubmissionStatus.pending) ...[
                            if (viewModel.isDirty)
                              const Text(
                                'Salva le modifiche prima di pubblicare o '
                                'rifiutare.',
                              ),
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                // One CTA chosen by the persisted draft: an
                                // end-date-only historical row still counts
                                // as an event and surfaces the start-date
                                // readiness error on publication.
                                FilledButton.tonal(
                                  onPressed:
                                      viewModel.isDirty ||
                                          viewModel.operationRunning
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
