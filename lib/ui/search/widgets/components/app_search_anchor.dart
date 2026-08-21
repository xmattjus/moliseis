import 'dart:async';
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

  /// Called when the search view closes, regardless of how it was dismissed:
  /// system back, barrier tap, the leading close button, or a programmatic
  /// [SearchController.closeView].
  ///
  /// The popup route is already popped when this runs, so the callback must
  /// only perform close-state cleanup and must not close the view again.
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
    ).call;
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

        child: SearchAnchor(
          isFullScreen: _isFullScreen,
          searchController: _searchController,
          viewBuilder: _buildViewBuilder,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchBar(
                controller: controller,
                hintText: widget.hintText,
                leading: widget.leading,
                trailing: <Widget>[
                  Icon(
                    Symbols.search,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
                onTap: controller.openView,
                elevation: WidgetStatePropertyAll<double>(
                  widget.elevation ?? 0,
                ),
                padding: WidgetStatePropertyAll<EdgeInsets>(
                  widget.leading == null
                      ? const EdgeInsets.symmetric(horizontal: 16)
                      : const EdgeInsets.only(left: 4, right: 16),
                ),
              ),
            );
          },
          // The leading close button pops the popup route through the
          // controller; the resulting popup `didPop` fires [viewOnClose],
          // which runs the host's close-state cleanup.
          viewLeading: BackButton(
            onPressed: () => _searchController.closeView(null),
          ),
          // Fires on every dismissal of the search view, including system
          // back, barrier dismissal, the leading close button, and
          // programmatic `closeView`.
          viewOnClose: widget.onBackPressed != null ? _handleOnClose : null,
          viewHintText: widget.hintText,
          viewOnSubmitted: (query) {
            unawaited(widget.viewModel.addToPastSearches.execute(query));

            _searchController.closeView(query);

            widget.onSubmitted?.call(query);
          },
          suggestionsBuilder: (context, controller) async {
            // The popup view route outlives this anchor State: it stays
            // alive during its exit transition and remains a listener on
            // the SearchController, so it can re-invoke this closure after
            // the host navigated away (goNamed) and unmounted the anchor.
            // Return the last cached result — a plain field read that
            // cannot throw — and skip all widget/context access.
            if (!mounted) return _lastHistory;

            // Capture before any await — the widget may unmount while the
            // debounce timer or the API call is in flight.
            final viewModel = widget.viewModel;
            final onSuggestionPressed = widget.onSuggestionPressed;

            if (controller.text.isEmpty) {
              final history = viewModel.pastSearches;

              return _lastHistory = _buildChips(
                viewModel: viewModel,
                texts: history,
                showDeleteIcon: true,
              );
            }

            final options = (await _debouncedSearch(
              controller.text,
            ))?.toList();

            // Guard again after the debounce await — the anchor may have
            // been unmounted while the timer was pending.
            if (!mounted) return _lastOptions;

            if (options == null) {
              return _lastOptions;
            }

            return _lastOptions = <Widget>[
              ListenableBuilder(
                listenable: viewModel.loadSuggestions,
                builder: (context, _) {
                  if (viewModel.loadSuggestions.completed) {
                    if (viewModel.suggestions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: EmptyView(
                          text: Text('Non è stato trovato alcun risultato.'),
                        ),
                      );
                    }

                    return SearchAnchorSuggestionList(
                      suggestions: viewModel.suggestions,
                      onSuggestionPressed: (content) {
                        unawaited(
                          viewModel.addToPastSearches.execute(
                            content.name,
                          ),
                        );

                        onSuggestionPressed(content);
                      },
                    );
                  }

                  if (viewModel.loadSuggestions.error) {
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
      ),
    );
  }

  List<Widget> _buildChips({
    required SearchViewModel viewModel,
    List<String> texts = const [],
    bool showDeleteIcon = false,
  }) {
    // The caller (suggestionsBuilder) guarantees `mounted` is true when
    // it reaches here. The tap callbacks below fire while the view is
    // open and the anchor is mounted; only the Future.delayed reset
    // can fire after unmount, and it has its own guard.

    return UnmodifiableListView(
      texts.map((e) {
        return RawChip(
          label: Text(e),
          onPressed: () {
            _searchController.text = e;

            unawaited(viewModel.addToPastSearches.execute(e));
          },
          deleteIcon: const Icon(Symbols.close),
          onDeleted: showDeleteIcon
              ? () async {
                  unawaited(viewModel.removeFromPastSearches.execute(e));
                  // Workaround to refresh the past searches list after
                  // removing a suggestion chip from the list.
                  _searchController.text = '\u200B';
                  await Future.delayed(Durations.medium1, () {
                    // The anchor may have been unmounted (host navigated
                    // away) during the delay. Writing to a disposed
                    // internal controller asserts in debug; writing to
                    // an external controller re-triggers suggestionsBuilder
                    // on the dead State. Either way, bail out.
                    if (!mounted) return;
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
    // The search view lives in its own popup route, which keeps rebuilding
    // `viewBuilder` on every animation tick while it fades out. If the anchor
    // has been unmounted (e.g. the host navigated away via goNamed right after
    // closeView), `State.context` would throw a null-check error. Return a
    // harmless widget for the remaining exit-transition frames.
    if (!mounted) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    if (_searchController.text.isEmpty) {
      children.addAll([
        const TextSectionDivider('Categorie'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CategoryContentWrap(
            chipBackgroundColor: context.colorScheme.surfaceContainerLow,
            onCategorySelected: (category) {
              _searchController.text = category.label;

              unawaited(
                widget.viewModel.addToPastSearches.execute(category.label),
              );
            },
          ),
        ),
      ]);

      if (_lastHistory.isNotEmpty) {
        children.addAll([
          const TextSectionDivider('Recenti'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: _lastHistory),
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

  /// Runs the host's close-state cleanup once the search view has been
  /// dismissed. The popup route is already popped by the time this runs, so
  /// no additional close is needed here.
  void _handleOnClose() {
    // viewOnClose fires from the popup route's didPop, which may run after
    // the anchor has been unmounted by a concurrent goNamed. Guard before
    // reading widget.
    if (!mounted) return;
    widget.onBackPressed?.call();
  }

  // Calls the "remote" API to search with the given query. Returns null when
  // the call has been made obsolete.
  Future<Iterable<ContentBase>?> _search([String? query]) async {
    // The debounce timer (500 ms) may fire after the anchor has been
    // unmounted by a goNamed submission while the debounce window was
    // still pending. Guard before any widget access.
    if (!mounted) return null;

    // If the query is too short, do not search.
    if (query == null || !SearchViewModel.isSearchQueryValid(query)) {
      // Resets the last shown options.
      _lastOptions = <Widget>[];

      return null;
    }

    _currentQuery = query;

    // Capture the view model before the await — the widget may unmount
    // while the load is in flight.
    final viewModel = widget.viewModel;
    await viewModel.loadSuggestions.execute(query);

    // The load may have completed after the anchor unmounted.
    if (!mounted) return null;

    final Iterable<ContentBase> options = viewModel.suggestions;

    // If another search happened after this one, throw away these options.
    if (_currentQuery != query) {
      return null;
    }
    _currentQuery = null;

    return options;
  }
}
