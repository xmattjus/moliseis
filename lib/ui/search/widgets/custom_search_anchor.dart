import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/ui/categories/widgets/category_chip.dart';
import 'package:moliseis/ui/core/ui/cards/card_attraction_list_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/debounceable.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class CustomSearchAnchor extends StatefulWidget {
  const CustomSearchAnchor({
    super.key,
    this.controller,
    this.hintText = 'Cerca per luogo, evento o categoria',
    this.leading,
    this.onSubmitted,
    this.onBackPressed,
    this.elevation,
    required this.onSuggestionPressed,
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

  final void Function(int attractionId) onSuggestionPressed;

  @override
  State<CustomSearchAnchor> createState() => _CustomSearchAnchorState();
}

class _CustomSearchAnchorState extends State<CustomSearchAnchor> {
  late final Debounceable<Iterable<int>?, String> _debouncedSearch;

  // The query currently being searched for. If null, there is no pending
  // request.
  String? _currentQuery;

  // The list of past searches.
  late List<Widget> _lastHistory = <Widget>[];

  // The most recent suggestions received from the API.
  late List<Widget> _lastOptions = <Widget>[];

  /// Creates an internal search controller if it has not been provided.
  SearchController? _internalSearchController;
  SearchController get _searchController =>
      widget.controller ?? (_internalSearchController ??= SearchController());

  late final SearchViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _debouncedSearch = debounce<Iterable<int>?, String>(
      duration: const Duration(milliseconds: 500),
      function: _search,
    );

    _viewModel = context.read();
  }

  @override
  void dispose() {
    _internalSearchController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen = ResponsiveBreakpoints.of(context).isMobile;

    /// Imposes constraints to the search bar dimensions to respect Material3
    /// guidelines.
    ///
    /// https://m3.material.io/components/search/specs#9df461f4-6c39-4f0a-8749-bdb63216d4af
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 360.0, maxWidth: 720.0),
      child: FocusScope(
        /// Prevents the [SearchBar] from automatically obtaining focus.
        canRequestFocus: false,

        /// Handles the [SearchAnchor] back gesture/button.
        child: BackButtonListener(
          child: SearchAnchor(
            isFullScreen: isFullScreen,
            searchController: _searchController,
            viewBuilder: _buildViewBuilder,
            builder: (context, controller) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SearchBar(
                  controller: controller,
                  hintText: widget.hintText,
                  leading: widget.leading,
                  trailing: [
                    Icon(
                      Icons.search_outlined,
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
              _viewModel.addToHistory.execute(query);

              _searchController.closeView(query);

              widget.onSubmitted?.call(query);
            },
            suggestionsBuilder: (context, controller) async {
              if (controller.text.isEmpty) {
                final history = _viewModel.history;

                return _lastHistory = _buildChips(
                  texts: history,
                  showDeleteIcon: true,
                );
              }

              final List<int>? options = (await _debouncedSearch(
                controller.text,
              ))?.toList();

              if (options == null) {
                return _lastOptions;
              }

              return _lastOptions = List<Widget>.generate(options.length, (
                index,
              ) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 0)
                      const Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          16.0,
                          16.0,
                          16.0,
                          8.0,
                        ),
                        child: TextSectionDivider('Risultati rapidi'),
                      ),
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        bottom: index == options.length ? 16.0 : 0,
                      ),
                      child: CardAttractionListItem(
                        options[index],
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        elevation: 0,
                        onPressed: () {
                          _viewModel.addToHistoryByAttractionId.execute(
                            options[index],
                          );

                          widget.onSuggestionPressed(options[index]);
                        },
                      ),
                    ),
                    if (index < options.length - 1)
                      Divider(color: Theme.of(context).colorScheme.surfaceDim),
                    // Adds some space to the last item of the list to prevent
                    // the bottom navigation bar from overlapping the results.
                    if (index == options.length - 1)
                      SizedBox(
                        height:
                            (isFullScreen
                                ? MediaQuery.maybePaddingOf(context)?.bottom ??
                                      0
                                : 0) +
                            16.0,
                      ),
                  ],
                );
              });
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

  UnmodifiableListView<Widget> _buildChips({
    List<String> texts = const [],
    bool showDeleteIcon = false,
  }) {
    return UnmodifiableListView(
      texts.map((e) {
        return RawChip(
          label: Text(e),
          onPressed: () {
            _searchController.text = e;

            _viewModel.addToHistory.execute(e);
          },
          deleteIcon: const Icon(Icons.close),
          onDeleted: showDeleteIcon
              ? () async {
                  _viewModel.removeFromHistory.execute(e);
                  _searchController.text = '\u200B';
                  await Future.delayed(Durations.medium1, () {
                    _searchController.text = '';
                  });
                }
              : null,
        );
      }),
    );
  }

  /// Lays out the suggestion list of the search view.
  Widget _buildViewBuilder(Iterable<Widget> suggestions) {
    if (_searchController.text.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8.0,
          children: <Widget>[
            const TextSectionDivider('Categorie'),
            Wrap(
              spacing: 8.0,
              children: UnmodifiableListView(
                _viewModel.types.map((AttractionType e) {
                  return CategoryChip(
                    element: e,
                    isSelected: false,
                    onPressed: () {
                      _searchController.text = e.label;

                      _viewModel.addToHistory.execute(e.label);
                    },
                  );
                }),
              ),
            ),
            if (_lastHistory.isNotEmpty) const TextSectionDivider('Recenti'),
            if (_lastHistory.isNotEmpty)
              Expanded(child: Wrap(spacing: 8.0, children: _lastHistory)),
          ],
        ),
      );
    }

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(children: UnmodifiableListView<Widget>(suggestions)),
    );
  }

  void _handleOnBackPressed() => widget.onBackPressed != null
      ? widget.onBackPressed!()
      : _searchController.closeView(null);

  // Calls the "remote" API to search with the given query. Returns null when
  // the call has been made obsolete.
  Future<Iterable<int>?> _search(String query) async {
    _currentQuery = query;

    await _viewModel.loadResults.execute(query);

    final Iterable<int> options = _viewModel.resultIds;

    // If another search happened after this one, throw away these options.
    if (_currentQuery != query) {
      return null;
    }
    _currentQuery = null;

    return options;
  }
}
