// TODO(xmattjus): Implement related results in search.
/*
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/machine_learning_icon.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';

class SearchResultRelatedSliverList extends StatelessWidget {
  const SearchResultRelatedSliverList({
    super.key,
    required this.onResultPressed,
    required this.viewModel,
  });

  final void Function(ContentBase content) onResultPressed;
  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel.loadRelatedResults,
      builder: (context, child) {
        if (viewModel.loadRelatedResults.completed) {
          if (viewModel.relatedResults.isNotEmpty) {
            return SliverMainAxisGroup(
              slivers: [
                const SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 8.0),
                  sliver: SliverToBoxAdapter(
                    child: TextSectionDivider('Altri risultati'),
                  ),
                ),
                ContentAdaptiveListGridView(
                  viewModel.relatedResults,
                  onPressed: onResultPressed,
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 16.0)),
              ],
            );
          } else {
            return const SliverToBoxAdapter(child: EmptyBox());
          }
        }

        if (viewModel.loadRelatedResults.error) {
          return const SliverToBoxAdapter(child: EmptyBox());
        }

        return const SliverToBoxAdapter(
          child: EmptyView(
            icon: MachineLearningIcon(),
            text: Text('Sto generando altri risultati...'),
          ),
        );
      },
    );
  }
}
*/
