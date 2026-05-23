import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/user_contribution/view_models/user_contribution_view_model.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class UserContributionMediaUploader extends StatelessWidget {
  const UserContributionMediaUploader({required this.viewModel, super.key});

  final UserContributionViewModel viewModel;

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
            listenable: Listenable.merge([
              viewModel.addMedia,
              viewModel.removeMediaAt,
              viewModel.retrieveLostMedia,
            ]),
            builder: (context, child) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  // The last widget of the list is a button to append new
                  // media to the user contribution.
                  if (viewModel.mediaFileList.length == index) {
                    if (viewModel.addMedia.running ||
                        viewModel.retrieveLostMedia.running) {
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
                      onPressed: () async => viewModel.addMedia.execute(),
                    );
                  }

                  return Stack(
                    key: ValueKey<String>(viewModel.mediaFileList[index].name),
                    alignment: Alignment.topRight,
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: appShapes.circular.cornerMedium,
                        child: Image.file(
                          File(viewModel.mediaFileList[index].path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      RawMaterialButton(
                        onPressed: () => viewModel.removeMediaAt.execute(index),
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
                itemCount: viewModel.mediaFileList.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
              );
            },
          ),
        ),
      ],
    );
  }
}
