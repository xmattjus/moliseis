import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/app_search_anchor.dart';
// import 'package:moliseis/ui/search/widgets/search_result_related_sliver_list.dart';
import 'package:moliseis/ui/search/widgets/search_result_sliver_list.dart';

class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({
    required this.query,
    required this.viewModel,
    super.key,
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

    _controller = SearchController()..text = widget.query;
  }

  @override
  void didUpdateWidget(covariant SearchResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.query == widget.query) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.text != widget.query) {
        _controller.text = widget.query;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      16,
                      kToolbarHeight + 16.0,
                      16,
                      8,
                    ),
                  ),
                ),
                SearchResultSliverList(
                  onResultPressed: (content) =>
                      _onSearchResultPressed(context, content),
                  onRetrySearchPressed: () {
                    unawaited(
                      widget.viewModel.loadResults.execute(widget.query),
                    );
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
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: AppSearchAnchor(
                    controller: _controller,
                    leading: const CustomBackButton(
                      padding: EdgeInsetsDirectional.zero,
                      backgroundColor: Colors.transparent,
                    ),
                    onSubmitted: _showSearchResults,
                    onSuggestionPressed: (content) {
                      _controller.closeView(content.name);
                      _showSearchResults(content.name);
                      // widget.viewModel.loadRelatedResultsIds.execute(
                      //   _controller.text,
                      // );
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

  void _showSearchResults(String query) {
    if (query.isEmpty) return;

    context.goNamed(
      RouteNames.homeSearchResult,
      queryParameters: {'q': query},
    );
  }

  void _onSearchResultPressed(BuildContext context, ContentBase content) {
    if (_controller.isOpen) {
      _controller.closeView(_controller.text);
    }

    GoRouter.of(context).goNamed(
      RouteNames.homeSearchResultPost,
      pathParameters: {
        'id': content.remoteId.toString(),
      },
      queryParameters: {
        'q': widget.query,
        'type': RouteParameters.contentTypeSlug(
          content is Event ? ContentType.event : ContentType.place,
        ),
      },
    );
  }
}
