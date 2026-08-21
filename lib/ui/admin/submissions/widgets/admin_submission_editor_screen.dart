import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';

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

  @override
  void initState() {
    super.initState();
    widget.viewModel.save.addListener(_handleSaveCompleted);
    widget.viewModel.changeStatus.addListener(_handleStatusChangeCompleted);
  }

  @override
  void dispose() {
    widget.viewModel.save.removeListener(_handleSaveCompleted);
    widget.viewModel.changeStatus.removeListener(_handleStatusChangeCompleted);
    super.dispose();
  }

  void _handleSaveCompleted() {
    if (!mounted) return;

    final save = widget.viewModel.save;
    if (save.completed) {
      context.pop(true);
    } else if (save.error) {
      showSnackBarGenericError(context: context);
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

  Future<void> _confirmStatusChange(AdminSubmissionStatus status) async {
    if (!mounted) return;

    final viewModel = widget.viewModel;
    final confirmationText = switch (status) {
      AdminSubmissionStatus.accepted =>
        'Confermi di accettare questo contributo?',
      AdminSubmissionStatus.rejected =>
        'Confermi di voler rifiutare questo contributo?',
      AdminSubmissionStatus.pending =>
        'Confermi di voler modificare lo stato di questo contributo?',
    };
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
    if (!mounted || confirmed != true) return;

    unawaited(viewModel.changeStatus.execute(status));
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
              if (viewModel.isEditMode && viewModel.assets.isNotEmpty)
                SliverList.list(
                  children: <Widget>[
                    const TextSectionDivider('Foto'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: viewModel.assets
                            .map(
                              (asset) => AppNetworkImage(
                                url: asset.url,
                                imageWidth: asset.width,
                                imageHeight: asset.height,
                                width: 100,
                                height: 100,
                              ),
                            )
                            .toList(),
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
                          if (viewModel.isDirty)
                            const Text(
                              'Salva le modifiche prima di cambiare lo stato.',
                            ),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              FilledButton.tonal(
                                onPressed:
                                    viewModel.isDirty ||
                                        viewModel.changeStatus.running
                                    ? null
                                    : () => unawaited(
                                        _confirmStatusChange(
                                          AdminSubmissionStatus.accepted,
                                        ),
                                      ),
                                child: const Text('Accetta'),
                              ),
                              FilledButton.tonal(
                                onPressed:
                                    viewModel.isDirty ||
                                        viewModel.changeStatus.running
                                    ? null
                                    : () => unawaited(
                                        _confirmStatusChange(
                                          AdminSubmissionStatus.rejected,
                                        ),
                                      ),
                                child: const Text('Rifiuta'),
                              ),
                            ],
                          ),
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
                      onPressed: viewModel.save.running ? null : _save,
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
