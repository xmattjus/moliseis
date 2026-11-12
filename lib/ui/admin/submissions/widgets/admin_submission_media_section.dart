import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_button.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';

/// Presents Admin media state while the Screen owns all command dispatch.
class AdminSubmissionMediaSection extends StatelessWidget {
  /// Reads one owner snapshot; callbacks retain the Screen's activation guards.
  const AdminSubmissionMediaSection({
    required this.viewModel,
    required this.onAdd,
    required this.onRemoveStaged,
    required this.onRemoveAsset,
    required this.onCancelPicker,
    super.key,
  });

  /// Existing state owner, observed by the enclosing Screen only.
  final AdminSubmissionEditorViewModel viewModel;

  /// Screen-owned picker admission, including unfocus and activation checks.
  final VoidCallback onAdd;

  /// Removes the original staged descriptor through its current owner.
  final ValueChanged<AdminSubmissionStagedAsset> onRemoveStaged;

  /// Opens the Screen-owned confirmation for a remote asset association.
  final ValueChanged<int> onRemoveAsset;

  /// Cancels only the picker nonce captured by the Screen.
  final VoidCallback onCancelPicker;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isEditMode &&
        !viewModel.hasLoadedDetail &&
        viewModel.stagedAssets.isEmpty) {
      return const SizedBox.shrink();
    }
    final status = viewModel.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TextSectionDivider('Foto'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('${viewModel.imageCount} / $kMaximumSubmissionAssetCount'),
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
              if (viewModel.stagedAssets.any((asset) => asset.progressInvalid))
                const Text(
                  'La conferma di una foto non è leggibile. '
                  'I file locali sono conservati; '
                  'la ripresa è sospesa.',
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...viewModel.stagedAssets.map(
                    (asset) => ContentSubmissionAssetListItem(
                      key: ValueKey('admin_staged_${asset.digest}'),
                      image: _AdminStagedAssetPreview(
                        key: ValueKey((
                          viewModel,
                          viewModel.activation?.generation,
                          asset.owner,
                          asset.digest,
                          asset.relativePath,
                        )),
                        viewModel: viewModel,
                        asset: asset,
                      ),
                      removeButtonSize: 48,
                      showRemoveIcon: viewModel.canCheckpoint,
                      onRemove: viewModel.operationRunning
                          ? null
                          : () => onRemoveStaged(asset),
                    ),
                  ),
                  ...viewModel.assets.map(
                    (asset) => ContentSubmissionAssetListItem(
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
                      showRemoveIcon: status == AdminSubmissionStatus.pending,
                      onRemove: !viewModel.canRequestDeleteAsset
                          ? null
                          : () => onRemoveAsset(asset.id),
                    ),
                  ),
                  if ((!viewModel.isEditMode ||
                          status == AdminSubmissionStatus.pending) &&
                      viewModel.imageCount < kMaximumSubmissionAssetCount &&
                      viewModel.canRequestAddAsset)
                    ContentSubmissionAddAssetButton(
                      key: const ValueKey<String>('admin_submission_add_asset'),
                      onPressed: !viewModel.canRequestAddAsset ? null : onAdd,
                    ),
                  if (viewModel.pickerWaiting)
                    TextButton(
                      onPressed: onCancelPicker,
                      child: const Text('Interrompi selezione'),
                    ),
                  if (viewModel.operationRunning)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CustomCircularProgressIndicator(size: 36),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Retains resolution for the keyed owner, activation and private file.
class _AdminStagedAssetPreview extends StatefulWidget {
  const _AdminStagedAssetPreview({
    required this.viewModel,
    required this.asset,
    required super.key,
  });

  final AdminSubmissionEditorViewModel viewModel;
  final AdminSubmissionStagedAsset asset;

  @override
  State<_AdminStagedAssetPreview> createState() =>
      _AdminStagedAssetPreviewState();
}

class _AdminStagedAssetPreviewState extends State<_AdminStagedAssetPreview> {
  late Future<Result<File>> _resolution;
  late final AdminDraftActivation? _activation;

  @override
  void initState() {
    super.initState();
    _activation = widget.viewModel.activation;
    _resolution = widget.viewModel.stagedAssetFile(widget.asset);
  }

  void _retry() {
    if (!mounted) return;
    if (!widget.viewModel.isActivationCurrent(_activation)) return;
    setState(() {
      _resolution = widget.viewModel.stagedAssetFile(widget.asset);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Result<File>>(
    future: _resolution,
    builder: (context, snapshot) => switch (snapshot.data) {
      Success<File>(:final value) => Image.file(
        value,
        width: contentSubmissionAssetSize.width,
        height: contentSubmissionAssetSize.height,
        cacheWidth:
            (contentSubmissionAssetSize.width *
                    MediaQuery.devicePixelRatioOf(context))
                .ceil(),
        cacheHeight:
            (contentSubmissionAssetSize.height *
                    MediaQuery.devicePixelRatioOf(context))
                .ceil(),
        fit: BoxFit.cover,
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 80, height: 80, child: Icon(Icons.image)),
          if (snapshot.connectionState == ConnectionState.done)
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'Riprova anteprima foto',
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    },
  );
}
