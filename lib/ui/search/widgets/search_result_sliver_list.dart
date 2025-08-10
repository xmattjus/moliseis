import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';

class SearchResultSliverList extends StatelessWidget {
  const SearchResultSliverList({
    super.key,
    this.onRetrySearchPressed,
    required this.onResultPressed,
    required this.viewModel,
  });

  final void Function()? onRetrySearchPressed;
  final void Function(int id) onResultPressed;
  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        ListenableBuilder(
          listenable: viewModel.loadResults,
          builder: (context, child) {
            if (viewModel.loadResults.running) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView.loading(text: Text('Caricamento in corso...')),
              );
            }

            if (viewModel.loadResults.error) {
              return SliverFillRemaining(
                hasScrollBody: false,
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

            if (viewModel.resultIds.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  text: Text('Non è stato trovato alcun risultato.'),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.only(bottom: 16.0),
              sliver: AttractionListViewResponsive(
                Future.sync(() => viewModel.resultIds),
                onPressed: onResultPressed,
              ),
            );
          },
        ),
      ],
    );
  }
}
