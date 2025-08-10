import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
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

  final void Function(int id) onResultPressed;
  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel.loadRelatedResults,
      builder: (context, child) {
        if (viewModel.loadRelatedResults.running) {
          return const SliverToBoxAdapter(
            child: EmptyView(
              icon: MachineLearningIcon(),
              text: Text('Sto generando altri risultati...'),
            ),
          );
        }

        if (viewModel.loadRelatedResults.completed &&
            viewModel.relatedResultIds.isNotEmpty) {
          return SliverMainAxisGroup(
            slivers: [
              const SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 8.0),
                sliver: SliverToBoxAdapter(
                  child: TextSectionDivider('Altri risultati'),
                ),
              ),
              AttractionListViewResponsive(
                Future.sync(() => viewModel.relatedResultIds),
                onPressed: onResultPressed,
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 16.0)),
            ],
          );
        }

        // Returns an empty box in case of error or no results to show.
        return const SliverToBoxAdapter(child: SizedBox());
      },
    );
  }
}
