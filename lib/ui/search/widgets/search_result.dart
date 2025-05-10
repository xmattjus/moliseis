import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/pad.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';

class SearchResult extends StatefulWidget {
  const SearchResult({
    super.key,
    required this.viewModel,
    this.query,
    this.refresh,
  });

  final SearchViewModel viewModel;
  final String? query;
  final String? refresh;

  @override
  State<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends State<SearchResult> {
  final SearchController _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query ?? '';

    if (query.isNotEmpty && widget.refresh == null) {
      _controller.text = query;
    }

    return Scaffold(
      appBar: const CustomAppBar.hidden(),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Pad(
                    t: kToolbarHeight + 16.0,
                    b: 8.0,
                    h: 16.0,
                    child: TextSectionDivider('Risultati'),
                  ),
                ),
                FutureBuilt<List<int>>(
                  widget.viewModel.getAttractionIdsByQuery(query),
                  onLoading: () {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CustomCircularProgressIndicator.withDelay(),
                      ),
                    );
                  },
                  onSuccess: (data) {
                    if (data.isEmpty || query.isEmpty) {
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
                          _controller.closeView(_controller.text);
                          GoRouter.of(context).goNamed(
                            RouteNames.exploreStory,
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
            ),
            Align(
              alignment: Alignment.topLeft,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: CustomSearchAnchor(
                  controller: _controller,
                  leading: IconButton(
                    onPressed: () => GoRouter.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  onSubmitted: (text) {
                    context.replaceNamed(
                      RouteNames.searchResult,
                      pathParameters: {'query': text},
                      queryParameters: {'refresh': 'true'},
                    );
                  },
                  onSuggestionPressed: (attractionId) {
                    _controller.closeView(_controller.text);
                    context.replaceNamed(
                      RouteNames.searchResult,
                      pathParameters: {'query': _controller.text},
                      queryParameters: {'refresh': 'true'},
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
