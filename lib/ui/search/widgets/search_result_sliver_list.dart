import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_list.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SearchResultSliverList extends StatelessWidget {
  const SearchResultSliverList({
    super.key,
    this.onRetrySearchPressed,
    required this.onResultPressed,
    required this.viewModel,
  });

  final void Function()? onRetrySearchPressed;
  final void Function(ContentBase content) onResultPressed;
  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        ListenableBuilder(
          listenable: viewModel.loadResults,
          builder: (context, child) {
            if (viewModel.loadResults.completed) {
              if (viewModel.results.isEmpty) {
                return const SliverToBoxAdapter(
                  child: EmptyView(
                    text: Text('Non è stato trovato alcun risultato.'),
                  ),
                );
              } else {
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  sliver: ContentAdaptiveListGridView(
                    viewModel.results,
                    onPressed: onResultPressed,
                  ),
                );
              }
            }

            if (viewModel.loadResults.error) {
              return SliverToBoxAdapter(
                child: EmptyView(
                  text: const Text(
                    'Si è verificato un errore durante il caricamento.',
                  ),
                  action: TextButton(
                    onPressed: onRetrySearchPressed,
                    child: const Text('Riprova'),
                  ),
                ),
              );
            }

            return ResponsiveBreakpoints.of(context).isMobile
                ? const SkeletonContentList.sliver(itemCount: 10)
                : const CardSkeletonGrid.sliver(itemCount: 10);
          },
        ),
      ],
    );
  }
}
