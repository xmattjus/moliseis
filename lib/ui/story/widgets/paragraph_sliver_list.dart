import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/story/view_models/paragraph_view_model.dart';
import 'package:moliseis/ui/story/widgets/paragraph_content.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ParagraphSliverList extends StatelessWidget {
  const ParagraphSliverList({
    super.key,
    required this.id,
    required this.viewModel,
  });

  final int id;
  final ParagraphViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel.loadParagraphs..execute(id),
      builder: (context, child) {
        if (viewModel.loadParagraphs.running) {
          return Skeletonizer.sliver(
            effect: CustomPulseEffect(context: context),
            ignoreContainers: false,
            child: SliverList.list(
              children: const <Widget>[
                SizedBox(height: 16.0),
                _ParagraphSkeleton(),
                SizedBox(height: 16.0),
                _ParagraphSkeleton(),
              ],
            ),
          );
        } else if (viewModel.loadParagraphs.error) {
          return SliverToBoxAdapter(
            child: EmptyView(
              action: TextButton(
                onPressed: () {
                  viewModel.loadParagraphs.execute(id);
                },
                child: const Text('Riprova'),
              ),
              text: const Text(
                'Si è verificato un problema durante il caricamento.',
              ),
            ),
          );
        }

        return SliverList.builder(
          itemBuilder: (context, index) {
            return ParagraphContent(paragraph: viewModel.paragraphs[index]);
          },
          itemCount: viewModel.paragraphs.length,
        );
      },
    );
  }
}

class _ParagraphSkeleton extends StatelessWidget {
  const _ParagraphSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Bone.text(style: CustomTextStyles.section(context)),
        // const Divider(height: 1, thickness: 1),
        const SizedBox(height: 8.0),
        Bone.text(style: CustomTextStyles.subtitle(context)),
        const SizedBox(height: 4.0),
        const Bone.text(words: 30),
        const SizedBox(height: 8.0),
        Bone.text(style: CustomTextStyles.subtitle(context)),
        const SizedBox(height: 4.0),
        const Bone.text(words: 30),
      ],
    );
  }
}
