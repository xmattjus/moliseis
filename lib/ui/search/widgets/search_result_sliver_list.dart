import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result_command.dart';

class SearchResultSliverList extends StatelessWidget {
  const SearchResultSliverList({
    required this.onResultPressed,
    required this.viewModel,
    this.onRetrySearchPressed,
    super.key,
  });

  final void Function()? onRetrySearchPressed;
  final void Function(ContentBase content) onResultPressed;
  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        ListenableBuilder(
          listenable: viewModel.loadResults.results,
          builder: (context, child) {
            final snapshot = viewModel.loadResults.results.value;
            if (snapshot.completed) {
              if (viewModel.results.isEmpty) {
                return const SliverToBoxAdapter(
                  child: EmptyView(
                    text: Text('Non è stato trovato alcun risultato.'),
                  ),
                );
              } else {
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 16),
                  sliver: ContentSliverGrid(
                    viewModel.results,
                    onPressed: onResultPressed,
                  ),
                );
              }
            }

            if (snapshot.hasFailure) {
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

            return const SkeletonContentSliverGrid();
          },
        ),
      ],
    );
  }
}
