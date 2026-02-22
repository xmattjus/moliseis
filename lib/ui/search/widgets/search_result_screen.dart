import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/app_search_anchor.dart';
// import 'package:moliseis/ui/search/widgets/search_result_related_sliver_list.dart';
import 'package:moliseis/ui/search/widgets/search_result_sliver_list.dart';

class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({
    super.key,
    required this.query,
    required this.viewModel,
  });

  final String query;
  final SearchViewModel viewModel;

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  late final SearchController _controller;

  @override
  void initState() {
    super.initState();

    _controller = SearchController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isNotEmpty) {
      _controller.text = widget.query;
    }

    return Scaffold(
      appBar: const CustomAppBar.hidden(),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: TextSectionDivider(
                    'Risultati',
                    padding: EdgeInsetsDirectional.fromSTEB(
                      16.0,
                      kToolbarHeight + 16.0,
                      16.0,
                      8.0,
                    ),
                  ),
                ),
                SearchResultSliverList(
                  onResultPressed: (content) =>
                      _onSearchResultPressed(context, content),
                  onRetrySearchPressed: () {
                    widget.viewModel.loadResults.execute(widget.query);
                  },
                  viewModel: widget.viewModel,
                ),
                /*
                SearchResultRelatedSliverList(
                  onResultPressed: (content) =>
                      _onSearchResultPressed(context, content),
                  viewModel: widget.viewModel,
                ),
                */
              ],
            ),
            Align(
              alignment: Alignment.topLeft,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: AppSearchAnchor(
                    controller: _controller,
                    leading: const CustomBackButton(
                      padding: EdgeInsetsDirectional.zero,
                      backgroundColor: Colors.transparent,
                    ),
                    onSubmitted: (text) {
                      widget.viewModel.loadResults.execute(text);
                      // widget.viewModel.loadRelatedResultsIds.execute(text);
                    },
                    onSuggestionPressed: (_) {
                      _controller.closeView(_controller.text);
                      widget.viewModel.loadResults.execute(_controller.text);
                      // widget.viewModel.loadRelatedResultsIds.execute(_controller.text);
                    },
                    viewModel: widget.viewModel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchResultPressed(BuildContext context, ContentBase content) {
    if (_controller.isOpen) {
      _controller.closeView(_controller.text);
    }

    GoRouter.of(context).goNamed(
      RouteNames.homeSearchResultPost,
      pathParameters: {
        'query': widget.query,
        'id': content.remoteId.toString(),
      },
      queryParameters: {
        'isEvent': (content is EventContent ? 'true' : 'false'),
      },
    );
  }
}
