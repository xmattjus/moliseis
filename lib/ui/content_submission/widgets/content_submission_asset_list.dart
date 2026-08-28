import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_button.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/result.dart';

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

class _ContentSubmissionAssetListState
    extends State<ContentSubmissionAssetList> {
  // The merged [Listenable] is built once and reused across builds to avoid
  // allocating a new [_MergedListenable] on every frame.
  late final Listenable _assetListenables = Listenable.merge([
    widget.viewModel.addAsset,
    widget.viewModel.removeAssetAt,
    widget.viewModel.retrieveLostAssets,
  ]);

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
            listenable: _assetListenables,
            builder: (context, child) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  if (widget.viewModel.assets.length == index) {
                    // Snows a CircularProgressIndicator when the selected
                    // assets are being addeded to the content submission.
                    if (widget.viewModel.addAsset.running ||
                        widget.viewModel.retrieveLostAssets.running) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: CustomCircularProgressIndicator(size: 36),
                      );
                    }

                    // Hides the button when the limit of assets to add has
                    // been reached.
                    if (widget.viewModel.assets.length >=
                        ContentSubmissionViewModel.maximumAssetCount) {
                      return const EmptyBox();
                    }

                    // Shows a button to append new assets to the content
                    // submission.
                    return ContentSubmissionAddAssetButton(
                      key: const ValueKey(
                        'content-submission-asset-list-add-button',
                      ),
                      onPressed: () async {
                        final viewModel = widget.viewModel;
                        await viewModel.addAsset.execute();
                        if (!mounted) return;

                        final result = viewModel.addAsset.result;
                        if (result case Success<AssetSelectionOutcome>(
                          :final value,
                        ) when value.hasRejections) {
                          _showAssetSelectionWarning(value);
                        }
                      },
                    );
                  }

                  return ContentSubmissionAssetListItem(
                    onPressed: () =>
                        widget.viewModel.removeAssetAt.execute(index),
                    image: Image.file(
                      File(widget.viewModel.assets[index].file.path),
                      width: contentSubmissionAssetSize.width,
                      height: contentSubmissionAssetSize.height,
                      cacheWidth: contentSubmissionAssetSize.width.toInt(),
                      cacheHeight: contentSubmissionAssetSize.height.toInt(),
                      fit: BoxFit.cover,
                    ),
                  );
                },
                itemCount: widget.viewModel.assets.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            32,
            2,
            32,
            0,
          ),
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
