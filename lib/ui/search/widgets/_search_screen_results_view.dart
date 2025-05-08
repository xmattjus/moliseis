part of 'search_screen.dart';

class SearchScreenResultsView extends StatelessWidget {
  final SearchViewModel uiSearchController;

  /// The search query to show results from.
  final String searchQuery;

  /// Called after one of the results has been acted upon.
  final VoidCallback? viewIsClosing;

  const SearchScreenResultsView(
    this.searchQuery, {
    super.key,
    required this.uiSearchController,
    this.viewIsClosing,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Pad(
            t: 16.0,
            b: 8.0,
            h: 16.0,
            child: CustomRichText(
              const Text('Risultati'),
              labelTextStyle: CustomTextStyles.section(context),
            ),
          ),
        ),
        FutureBuilt<List<int>>(
          uiSearchController.getAttractionIdsByQuery(searchQuery),
          onLoading: () {
            return const SliverFillRemaining(
              // hasScrollBody: false,
              child: Center(child: CustomCircularProgressIndicator.withDelay()),
            );
          },
          onSuccess: (data) {
            if (data.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  text: Text('Non è stato trovato alcun risultato.'),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsetsDirectional.only(bottom: 16.0),
              sliver: AttractionListViewResponsive(
                Future.sync(() => data),
                onPressed: (attractionId) {
                  GoRouter.of(context).goNamed(
                    RouteNames.searchStory,
                    pathParameters: {'id': attractionId.toString()},
                  );
                },
              ),
            );
          },
          onError: (error) {
            return SliverToBoxAdapter(child: Text('$error'));
          },
        ),
      ],
    );
  }
}
