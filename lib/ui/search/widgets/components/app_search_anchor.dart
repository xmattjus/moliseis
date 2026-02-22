import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/category/widgets/category_content_wrap.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_skeleton_list.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_suggestion_list.dart';
import 'package:moliseis/utils/debounceable.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppSearchAnchor extends StatefulWidget {
  const AppSearchAnchor({
    super.key,
    this.controller,
    this.hintText = 'Cerca per luogo, evento o categoria',
    this.leading,
    this.onSubmitted,
    this.onBackPressed,
    this.elevation,
    required this.onSuggestionPressed,
    required this.viewModel,
  });

  /// An optional controller that allows to interact with the search bar from
  /// other widgets.
  ///
  /// If this is null, one internal search controller is created automatically.
  final SearchController? controller;

  /// Text that suggests what sort of input the field accepts.
  ///
  /// Displayed at the same location on the screen where text may be entered
  /// when the input is empty.
  ///
  /// Defaults to null.
  final String hintText;

  /// A widget to display before the text input field.
  ///
  /// Typically the [leading] widget is an [Icon] or an [IconButton].
  final Widget? leading;

  /// Called when the user indicates that they are done editing the text in the
  /// field.
  final void Function(String text)? onSubmitted;

  /// Called when the user indicates that they want to close the [SearchAnchor].
  final VoidCallback? onBackPressed;

  final double? elevation;

  final void Function(ContentBase content) onSuggestionPressed;

  final SearchViewModel viewModel;

  @override
  State<AppSearchAnchor> createState() => _AppSearchAnchorState();
}

class _AppSearchAnchorState extends State<AppSearchAnchor> {
  late final Debounceable<Iterable<ContentBase>?, String> _debouncedSearch;

  /// The query currently being searched for. If null, there is no pending
  /// request.
  String? _currentQuery;

  /// The list of past searches.
  late List<Widget> _lastHistory = <Widget>[];

  /// The most recent suggestions received from the API.
  late List<Widget> _lastOptions = <Widget>[];

  /// Creates an internal search controller if it has not been provided.
  SearchController? _internalSearchController;
  SearchController get _searchController =>
      widget.controller ?? (_internalSearchController ??= SearchController());

  late bool _isFullScreen;

  @override
  void initState() {
    super.initState();

    _debouncedSearch = debounce<Iterable<ContentBase>?, String>(
      duration: const Duration(milliseconds: 500),
      function: _search,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isFullScreen = context.windowSizeClass.isCompact;
  }

  @override
  void dispose() {
    _internalSearchController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSizes = context.appSizes;
    // Imposes constraints to the search bar dimensions to respect Material3
    // guidelines.
    //
    // https://m3.material.io/components/search/specs#9df461f4-6c39-4f0a-8749-bdb63216d4af
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: appSizes.searchBarMinWidth,
        maxWidth: appSizes.searchBarMaxWidth,
      ),
      child: FocusScope(
        /// Prevents the [SearchBar] from automatically obtaining focus.
        canRequestFocus: false,

        /// Handles the [SearchAnchor] back gesture/button.
        child: BackButtonListener(
          child: SearchAnchor(
            isFullScreen: _isFullScreen,
            searchController: _searchController,
            viewBuilder: _buildViewBuilder,
            builder: (context, controller) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SearchBar(
                  controller: controller,
                  hintText: widget.hintText,
                  leading: widget.leading,
                  trailing: <Widget>[
                    Icon(
                      Symbols.search,
                      size: 24.0,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                  onTap: controller.openView,
                  elevation: WidgetStatePropertyAll<double>(
                    widget.elevation ?? 0,
                  ),
                  padding: WidgetStatePropertyAll<EdgeInsets>(
                    widget.leading == null
                        ? const EdgeInsets.symmetric(horizontal: 16.0)
                        : const EdgeInsets.only(left: 4.0, right: 16.0),
                  ),
                ),
              );
            },
            viewLeading: BackButton(onPressed: _handleOnBackPressed),
            viewHintText: widget.hintText,
            viewOnSubmitted: (query) {
              widget.viewModel.addToHistory.execute(query);

              _searchController.closeView(query);

              widget.onSubmitted?.call(query);
            },
            suggestionsBuilder: (context, controller) async {
              if (controller.text.isEmpty) {
                final history = widget.viewModel.history;

                return _lastHistory = _buildChips(
                  texts: history,
                  showDeleteIcon: true,
                );
              }

              final List<ContentBase>? options = (await _debouncedSearch(
                controller.text,
              ))?.toList();

              if (options == null) {
                return _lastOptions;
              }

              return _lastOptions = <Widget>[
                ListenableBuilder(
                  listenable: widget.viewModel.loadSuggestions,
                  builder: (context, _) {
                    if (widget.viewModel.loadSuggestions.completed) {
                      if (widget.viewModel.results.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: EmptyView(
                            text: Text('Non è stato trovato alcun risultato.'),
                          ),
                        );
                      }

                      return SearchAnchorSuggestionList(
                        suggestions: widget.viewModel.results,
                        onSuggestionPressed: (content) {
                          widget.viewModel.addToHistory.execute(content.name);

                          widget.onSuggestionPressed(content);
                        },
                      );
                    }

                    if (widget.viewModel.loadSuggestions.error) {
                      return const ListTile(
                        title: Text('Si è verificato un problema, riprova.'),
                      );
                    }

                    return const SearchAnchorSkeletonList();
                  },
                ),
              ];
            },
          ),
          onBackButtonPressed: () async {
            if (_searchController.isOpen) {
              _handleOnBackPressed();
              return true;
            }
            return false;
          },
        ),
      ),
    );
  }

  List<Widget> _buildChips({
    List<String> texts = const [],
    bool showDeleteIcon = false,
  }) {
    return UnmodifiableListView(
      texts.map((e) {
        return RawChip(
          label: Text(e),
          onPressed: () {
            _searchController.text = e;

            widget.viewModel.addToHistory.execute(e);
          },
          deleteIcon: const Icon(Symbols.close),
          onDeleted: showDeleteIcon
              ? () async {
                  widget.viewModel.removeFromHistory.execute(e);
                  _searchController.text = '\u200B';
                  await Future.delayed(Durations.medium1, () {
                    _searchController.text = '';
                  });
                }
              : null,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        );
      }),
    );
  }

  /// Lays out the suggestion list of the search view.
  Widget _buildViewBuilder(Iterable<Widget> suggestions) {
    final children = <Widget>[];
    if (_searchController.text.isEmpty) {
      children.addAll([
        const TextSectionDivider('Categorie'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CategoryContentWrap(
            chipBackgroundColor: context.colorScheme.surfaceContainerLow,
            onCategorySelected: (category) {
              _searchController.text = category.label;

              widget.viewModel.addToHistory.execute(category.label);
            },
          ),
        ),
      ]);

      if (_lastHistory.isNotEmpty) {
        children.addAll([
          const TextSectionDivider('Recenti'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(spacing: 8.0, children: _lastHistory),
          ),
        ]);
      }
    } else {
      children.addAll(suggestions);
    }

    children.add(
      SizedBox(height: _isFullScreen ? context.bottomPadding : 16.0),
    );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(children: children),
      ),
    );
  }

  void _handleOnBackPressed() => widget.onBackPressed != null
      ? widget.onBackPressed!()
      : _searchController.closeView(null);

  // Calls the "remote" API to search with the given query. Returns null when
  // the call has been made obsolete.
  Future<Iterable<ContentBase>?> _search(String query) async {
    // If the query is too short, do not search.
    if (query.length < 3) {
      // Resets the last shown options.
      _lastOptions = <Widget>[];

      return null;
    }

    _currentQuery = query;

    await widget.viewModel.loadSuggestions.execute(query);

    final Iterable<ContentBase> options = widget.viewModel.results;

    // If another search happened after this one, throw away these options.
    if (_currentQuery != query) {
      return null;
    }
    _currentQuery = null;

    return options;
  }
}
