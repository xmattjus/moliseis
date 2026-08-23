import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
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
  var _statusDialogOpen = false;
  var _saveCompletedWhileStatusDialogOpen = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.save.addListener(_handleSaveCompleted);
    widget.viewModel.changeStatus.addListener(_handleStatusChangeCompleted);
    widget.viewModel.addAsset.addListener(_handleAddAssetCompleted);
    widget.viewModel.deleteAsset.addListener(_handleDeleteAssetCompleted);
  }

  @override
  void dispose() {
    widget.viewModel.save.removeListener(_handleSaveCompleted);
    widget.viewModel.changeStatus.removeListener(_handleStatusChangeCompleted);
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

  void _handleStatusChangeCompleted() {
    if (!mounted) return;

    final changeStatus = widget.viewModel.changeStatus;
    if (changeStatus.completed) {
      context.pop(true);
    } else if (changeStatus.error) {
      showSnackBarGenericError(context: context);
    }
  }

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

  Future<void> _confirmStatusChange({
    required AdminSubmissionStatus status,
    required String confirmationText,
  }) async {
    if (!mounted) return;

    final viewModel = widget.viewModel;
    if (viewModel.operationRunning) return;

    _statusDialogOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(confirmationText),
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

      unawaited(viewModel.changeStatus.execute(status));
    } finally {
      _statusDialogOpen = false;
      _saveCompletedWhileStatusDialogOpen = false;
    }
  }

  Future<void> _confirmAssetDeletion(int assetId) async {
    if (!mounted) return;

    final viewModel = widget.viewModel;
    if (viewModel.operationRunning) return;

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
    if (_formKey.currentState?.validate() ?? false) {
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
          viewModel.changeStatus,
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
                    ContentSubmissionFields(
                      formKey: _formKey,
                      category: viewModel.category,
                      city: viewModel.city,
                      name: viewModel.name,
                      description: viewModel.description,
                      descriptionDelta: viewModel.descriptionDelta,
                      startDate: viewModel.startDate,
                      endDate: viewModel.endDate,
                      onCategorySelected: viewModel.setCategory,
                      onCategoryDeleted: () => viewModel.setCategory(null),
                      onCityChanged: viewModel.setCity,
                      onNameChanged: viewModel.setName,
                      onDescriptionChanged: viewModel.setDescription,
                      onStartDateChanged: viewModel.setStartDate,
                      onStartTimeChanged: viewModel.setStartTime,
                      onEndDateChanged: viewModel.setEndDate,
                    ),
                  ],
                ),
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
                                        : () => unawaited(
                                            viewModel.addAsset.execute(),
                                          ),
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
                          Text(status.label),
                          if (status == AdminSubmissionStatus.pending) ...[
                            if (viewModel.isDirty)
                              const Text(
                                'Salva le modifiche prima di '
                                'cambiare lo stato.',
                              ),
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                FilledButton.tonal(
                                  onPressed:
                                      viewModel.isDirty ||
                                          viewModel.operationRunning
                                      ? null
                                      : () => unawaited(
                                          _confirmStatusChange(
                                            status:
                                                AdminSubmissionStatus.accepted,
                                            confirmationText:
                                                'Confermi di accettare questo '
                                                'contributo?',
                                          ),
                                        ),
                                  child: const Text('Accetta'),
                                ),
                                FilledButton.tonal(
                                  onPressed:
                                      viewModel.isDirty ||
                                          viewModel.operationRunning
                                      ? null
                                      : () => unawaited(
                                          _confirmStatusChange(
                                            status:
                                                AdminSubmissionStatus.rejected,
                                            confirmationText:
                                                'Confermi di voler rifiutare '
                                                'questo contributo?',
                                          ),
                                        ),
                                  child: const Text('Rifiuta'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
