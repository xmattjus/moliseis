import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_list.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/extensions.dart';

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

            return WindowSizeProvider.of(context).isCompact
                ? const SkeletonContentList.sliver(itemCount: 10)
                : SkeletonContentGrid.sliver(
                    itemCount: context.gridViewColumnCount,
                  );
          },
        ),
      ],
    );
  }
}
