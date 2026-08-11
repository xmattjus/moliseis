import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class ContentSubmissionAddAssetForm extends StatefulWidget {
  const ContentSubmissionAddAssetForm({required this.viewModel, super.key});

  final ContentSubmissionViewModel viewModel;

  @override
  State<ContentSubmissionAddAssetForm> createState() =>
      _ContentSubmissionAddAssetFormState();
}

class _ContentSubmissionAddAssetFormState
    extends State<ContentSubmissionAddAssetForm> {
  // The merged [Listenable] is built once and reused across builds to avoid
  // allocating a new [_MergedListenable] on every frame.
  late final Listenable _assetListenables = Listenable.merge([
    widget.viewModel.addAsset,
    widget.viewModel.removeAssetAt,
    widget.viewModel.retrieveLostAssets,
  ]);

  void _showTooLargeSnackBar(List<String> rejectedNames) {
    final count = rejectedNames.length;
    final names = rejectedNames.take(3).join(', ');
    final suffix = count > 3 ? ' (+${count - 3})' : '';
    final message =
        '$count file${count == 1 ? '' : 's'} '
        'oltre il limite di 10 MB: $names$suffix';

    showSnackBar(
      context: context,
      textContent: message,
      type: SnackBarType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appShapes = context.appShapes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const TextSectionDivider(
          'Foto',
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        SizedBox(
          height: 72,
          child: ListenableBuilder(
            listenable: _assetListenables,
            builder: (context, child) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  // The last widget of the list is a button to append new
                  // assets to the content submission.
                  if (widget.viewModel.assets.length == index) {
                    if (widget.viewModel.addAsset.running ||
                        widget.viewModel.retrieveLostAssets.running) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: CustomCircularProgressIndicator(size: 36),
                      );
                    }

                    return CardBase(
                      width: 72,
                      height: 72,
                      elevation: 0,
                      child: const Center(
                        child: Icon(Symbols.add_a_photo, size: 24),
                      ),
                      onPressed: () async {
                        final viewModel = widget.viewModel;
                        await viewModel.addAsset.execute().then((_) {
                          final result = viewModel.addAsset.result;
                          if (result case Success<AssetSelectionOutcome>(
                            :final value,
                          ) when value.hasRejections) {
                            if (!mounted) return;
                            _showTooLargeSnackBar(value.rejectedNames);
                          }
                        });
                      },
                    );
                  }

                  return Stack(
                    key: ValueKey<String>(
                      widget.viewModel.assets[index].digest,
                    ),
                    alignment: Alignment.topRight,
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: appShapes.circular.cornerMedium,
                        child: Image.file(
                          File(widget.viewModel.assets[index].file.path),
                          width: 72,
                          height: 72,
                          cacheWidth: 72,
                          cacheHeight: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      RawMaterialButton(
                        onPressed: () =>
                            widget.viewModel.removeAssetAt.execute(index),
                        fillColor: context.colorScheme.primaryFixedDim,
                        elevation: 0,
                        constraints: const BoxConstraints(
                          maxWidth: 56,
                          maxHeight: 56,
                        ),
                        padding: const EdgeInsets.all(4),
                        shape: RoundedRectangleBorder(
                          borderRadius: appShapes.circular.cornerMedium,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        child: const Icon(Symbols.remove, size: 20),
                      ),
                    ],
                  );
                },
                itemCount: widget.viewModel.assets.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
              );
            },
          ),
        ),
      ],
    );
  }
}
