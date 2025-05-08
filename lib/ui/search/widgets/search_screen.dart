import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/pad.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';
import 'package:provider/provider.dart';

part '_search_screen_home_view.dart';
part '_search_screen_results_view.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = SearchController();

  late final SearchViewModel _viewModel;

  /// Whether the [SearchScreenResultsView] is visible or not.
  bool _searchResultsVisible = false;

  @override
  void initState() {
    super.initState();

    _viewModel = context.read();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Pad(
      t: kToolbarHeight,
      child:
          !_searchResultsVisible
              ? const SearchScreenHomeView()
              : SearchScreenResultsView(
                _searchController.text,
                uiSearchController: _viewModel,
                viewIsClosing: _hideSearchResults,
              ),
    );

    final searchBar = Align(
      alignment: Alignment.topLeft,
      child: CustomSearchAnchor(
        controller: _searchController,
        leading:
            _searchResultsVisible
                ? BackButton(onPressed: _hideSearchResults)
                : null,
        // onTap: () => _searchController.openView(),
        onSubmitted: (text) => _showSearchResults(text),
        onBackPressed: _hideSearchResults,
        onSuggestionPressed: (attractionId) {
          _showSearchResults(_searchController.text);
          /*
          GoRouter.of(context).goNamed(
            RouteNames.searchStory,
            pathParameters: {'id': attractionId.toString()},
          );
           */
        },
      ),
    );

    return PopScope(
      canPop: !_searchResultsVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _hideSearchResults();
      },
      child: Scaffold(
        appBar: const CustomAppBar.hidden(),
        body: SafeArea(child: Stack(children: [content, searchBar])),
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
      ),
    );
  }

  void _showSearchResults(String text) {
    // Rebuilds only when there are search results to show.
    if (text.isEmpty) {
      return;
    }

    context.goNamed(RouteNames.searchResult, pathParameters: {'query': text});

    _searchController.clear();
  }

  void _hideSearchResults() {
    final wasSearchViewOpen = _searchController.isOpen;

    if (wasSearchViewOpen) {
      /// _searchController.closeView() internally just calls
      /// Navigator.of(context).pop().
      _searchController.closeView(_searchController.text);
    }

    // If the search view close animation is running waits for it to finish
    // before clearing the attached search controller to prevent graphical
    // glitches.
    Future.delayed(
      Duration(milliseconds: wasSearchViewOpen ? 200 : 0),
      () => _searchController.clear(),
    );

    setState(() {
      _searchResultsVisible = false;
    });
  }
}
