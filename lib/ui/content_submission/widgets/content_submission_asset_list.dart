import 'dart:io' show File;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_button.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

/// Horizontal scrollable list of selected assets with add/remove actions.
///
/// Renders a `ContentSubmissionAssetListItem` for each asset and, at the
/// end, a trailing slot whose contents depend on the current view-model
/// state: a progress indicator while assets are being added or restored,
/// nothing once the maximum of 5 is reached, otherwise the
/// `ContentSubmissionAddAssetButton`. Tap a thumbnail's remove overlay to
/// delete that asset, or tap the add button to open the platform image
/// picker. Assets larger than 10 MB are rejected by the view model and
/// surface here as a warning snack bar.
class ContentSubmissionAssetList extends StatefulWidget {
  /// Creates an asset list for a content submission.
  const ContentSubmissionAssetList({required this.viewModel, super.key});

  /// ViewModel that manages the submission's asset state and operations.
  final ContentSubmissionViewModel viewModel;

  @override
  State<ContentSubmissionAssetList> createState() =>
      _ContentSubmissionAssetListState();
}

/// Feedback belongs only to the execution admitted by this consumer.
class _SelectionFeedback {
  _SelectionFeedback(this.owner)
    : clientSubmissionId = owner.state.clientSubmissionId,
      awaitingInitialization =
          owner.loadState == ContentSubmissionDraftLoadState.loading;

  final ContentSubmissionViewModel owner;
  String clientSubmissionId;
  bool awaitingInitialization;
  Object? runningSnapshot;
}

class _ContentSubmissionAssetListState
    extends State<ContentSubmissionAssetList> {
  late ContentSubmissionViewModel _owner;
  _SelectionFeedback? _selection;

  @override
  void initState() {
    super.initState();
    _owner = widget.viewModel;
    _owner.addListener(_observeSelection);
  }

  @override
  void didUpdateWidget(covariant ContentSubmissionAssetList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(_owner, widget.viewModel)) return;
    _owner.removeListener(_observeSelection);
    _selection = null;
    _owner = widget.viewModel;
    _owner.addListener(_observeSelection);
  }

  @override
  void dispose() {
    _selection = null;
    _owner.removeListener(_observeSelection);
    super.dispose();
  }

  bool _isCurrentOwner(ContentSubmissionViewModel owner) {
    if (!mounted) return false;
    if (!identical(widget.viewModel, owner)) return false;
    final providedOwner = context.read<ContentSubmissionViewModel?>();
    return providedOwner == null || identical(providedOwner, owner);
  }

  void _requestAddAsset(ContentSubmissionViewModel owner) {
    if (!mounted) return;
    if (!_isCurrentOwner(owner) || owner.isAddingAsset) return;
    final selection = _SelectionFeedback(owner);
    _selection = selection;
    if (!owner.requestAddAsset() && identical(_selection, selection)) {
      _selection = null;
    }
  }

  void _observeSelection() {
    if (!mounted) return;
    final selection = _selection;
    if (selection == null) return;
    final owner = selection.owner;
    if (!_isCurrentOwner(owner)) {
      _selection = null;
      return;
    }
    if (selection.awaitingInitialization &&
        owner.loadState == ContentSubmissionDraftLoadState.ready) {
      selection
        ..clientSubmissionId = owner.state.clientSubmissionId
        ..awaitingInitialization = false;
    }
    if (!selection.awaitingInitialization &&
        selection.clientSubmissionId != owner.state.clientSubmissionId) {
      _selection = null;
      return;
    }
    final snapshot = owner.addAssetSnapshot;
    if (snapshot.isRunning) {
      if (selection.runningSnapshot == null) {
        selection.runningSnapshot = snapshot;
      } else if (!identical(selection.runningSnapshot, snapshot)) {
        // A reentrant caller admitted a different execution before feedback.
        _selection = null;
      }
      return;
    }
    if (owner.isAddingAsset || selection.runningSnapshot == null) return;
    _selection = null;
    if (!snapshot.completed ||
        !_isCurrentOwner(owner) ||
        owner.state.clientSubmissionId != selection.clientSubmissionId) {
      return;
    }
    if (snapshot.data case Success<AssetSelectionOutcome>(
      :final value,
    ) when value.hasRejections) {
      _showAssetSelectionWarning(value);
    }
  }

  void _showAssetSelectionWarning(AssetSelectionOutcome outcome) {
    final message = switch ((
      outcome.hasOversizedRejections,
      outcome.hasAssetLimitRejections,
    )) {
      (false, false) => null,
      (true, false) => 'Le foto oltre i 10 MB sono state escluse',
      (false, true) =>
        'Le foto oltre il limite di '
            '${ContentSubmissionViewModel.maximumAssetCount} sono state '
            'escluse',
      (true, true) =>
        'Le foto oltre i 10 MB o il limite di '
            '${ContentSubmissionViewModel.maximumAssetCount} sono state '
            'escluse',
    };

    if (message == null) return;

    showSnackBar(
      context: context,
      textContent: message,
      type: SnackBarType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const TextSectionDivider(
          'Foto',
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        SizedBox(
          height: contentSubmissionAssetSize.height,
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, child) {
              final assets = viewModel.assets;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  if (assets.length == index) {
                    // Snows a CircularProgressIndicator when the selected
                    // assets are being addeded to the content submission.
                    if (viewModel.isAddingAsset ||
                        viewModel.isRetrievingLostAssets) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: CustomCircularProgressIndicator(size: 36),
                      );
                    }

                    // Hides the button when the limit of assets to add has
                    // been reached.
                    if (assets.length >=
                        ContentSubmissionViewModel.maximumAssetCount) {
                      return const EmptyBox();
                    }

                    // Shows a button to append new assets to the content
                    // submission.
                    return ContentSubmissionAddAssetButton(
                      key: const ValueKey(
                        'content-submission-asset-list-add-button',
                      ),
                      onPressed: () => _requestAddAsset(viewModel),
                    );
                  }

                  final renderedOwner = viewModel;
                  final renderedClientSubmissionId =
                      renderedOwner.state.clientSubmissionId;
                  final renderedIndex = index;
                  final asset = assets[index];
                  final renderedDigest = asset.digest;
                  return ContentSubmissionAssetListItem(
                    onRemove: () {
                      if (!mounted) return;
                      if (!_isCurrentOwner(renderedOwner) ||
                          renderedOwner.state.clientSubmissionId !=
                              renderedClientSubmissionId) {
                        return;
                      }
                      final currentAssets = renderedOwner.assets;
                      if (renderedIndex < 0 ||
                          renderedIndex >= currentAssets.length ||
                          currentAssets[renderedIndex].digest !=
                              renderedDigest) {
                        return;
                      }
                      renderedOwner.requestRemoveAssetAt(renderedIndex);
                    },
                    image: Image.file(
                      File(asset.file.path),
                      width: contentSubmissionAssetSize.width,
                      height: contentSubmissionAssetSize.height,
                      cacheWidth: contentSubmissionAssetSize.width.toInt(),
                      cacheHeight: contentSubmissionAssetSize.height.toInt(),
                      fit: BoxFit.cover,
                    ),
                  );
                },
                itemCount: assets.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(32, 2, 32, 0),
          child: Builder(
            builder: (context) {
              return Text(
                'È possibile inserire al massimo '
                '${ContentSubmissionViewModel.maximumAssetCount} foto e ogni '
                'foto può essere grande al massimo 10 megabyte (MB)',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ),
      ],
    );
  }
}
