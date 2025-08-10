import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/suggestion/view_models/suggestion_view_model.dart';

class SuggestionImageGallery extends StatelessWidget {
  const SuggestionImageGallery({super.key, required this.viewModel});

  final SuggestionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: TextSectionDivider('Foto'),
        ),
        SizedBox(
          height: 72.0,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              viewModel.addImages,
              viewModel.removeImageAtIndex,
            ]),
            builder: (context, child) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  // The last widget of the list is a button to append new
                  // images to the suggestion.
                  if (viewModel.mediaFileList.length == index) {
                    if (viewModel.addImages.running) {
                      return const Padding(
                        padding: EdgeInsets.all(18.0),
                        child: CustomCircularProgressIndicator(size: 36.0),
                      );
                    }

                    return CardBase(
                      width: 72.0,
                      height: 72.0,
                      elevation: 0,
                      child: const Center(
                        child: Icon(Icons.add_a_photo_outlined, size: 24.0),
                      ),
                      onPressed: () async =>
                          await viewModel.addImages.execute(),
                    );
                  }

                  return Stack(
                    key: ValueKey<String>(viewModel.mediaFileList[index].name),
                    alignment: Alignment.topRight,
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Shapes.medium),
                        child: CustomImage.file(
                          File(viewModel.mediaFileList[index].path),
                          width: 72.0,
                          height: 72.0,
                          imageWidth: 1000,
                          imageHeight: 1000,
                        ),
                      ),
                      RawMaterialButton(
                        onPressed: () =>
                            viewModel.removeImageAtIndex.execute(index),
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                        elevation: 0,
                        constraints: const BoxConstraints(
                          maxWidth: 56.0,
                          maxHeight: 56.0,
                        ),
                        padding: const EdgeInsets.all(4.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Shapes.medium),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        child: const Icon(Icons.remove, size: 20.0),
                      ),
                    ],
                  );
                },
                itemCount: viewModel.mediaFileList.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8.0),
              );
            },
          ),
        ),
      ],
    );
  }
}
