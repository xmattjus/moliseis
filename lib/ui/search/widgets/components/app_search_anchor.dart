import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/category/widgets/category_content_wrap.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_skeleton_list.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_suggestion_list.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result_command.dart';

class AppSearchAnchor extends StatefulWidget {
  const AppSearchAnchor({
    required this.onSuggestionPressed,
    required this.viewModel,
    this.controller,
    this.hintText = 'Cerca per luogo, evento o categoria',
    this.leading,
    this.onSubmitted,
    this.onBackPressed,
    this.elevation,
    super.key,
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
  Timer? _suggestionTimer;
  String? _lastSuggestionInput;

  /// The list of past searches.
  late List<Widget> _lastHistory = <Widget>[];

  /// The most recent suggestions received from the API.
  late List<Widget> _lastOptions = <Widget>[];

  /// Creates an internal search controller if it has not been provided.
  SearchController? _internalSearchController;
  SearchController get _searchController =>
      widget.controller ?? (_internalSearchController ??= SearchController());

  late bool _isFullScreen;
  Object _popupSession = Object();
  Object? _confirmationToken;
  bool _popupOpen = false;
  bool _closingConfirmation = false;

  bool _owns(SearchViewModel owner, SearchController controller) {
    if (!mounted) return false;
    return identical(widget.viewModel, owner) &&
        identical(_searchController, controller);
  }

  bool _admits(
    SearchViewModel owner,
    SearchController controller,
    Object session,
  ) =>
      _owns(owner, controller) &&
      _popupOpen &&
      identical(_popupSession, session) &&
      _confirmationToken == null &&
      controller.isOpen;

  void _confirm(
    SearchViewModel owner,
    SearchController controller,
    Object session,
    String query,
    VoidCallback navigate,
  ) {
    if (!_admits(owner, controller, session)) return;
    final token = Object();
    _confirmationToken = token;
    owner.addToPastSearches(query);
    if (!_owns(owner, controller) ||
        !identical(_confirmationToken, token) ||
        !controller.isOpen) {
      return;
    }
    _closingConfirmation = true;
    controller.closeView(query);
    _closingConfirmation = false;
    // Our own close consumes admission, preserving this follow-through.
    if (!_owns(owner, controller) || !identical(_confirmationToken, token)) {
      return;
    }
    navigate();
  }

  @override
  void didUpdateWidget(covariant AppSearchAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel) ||
        !identical(oldWidget.controller, widget.controller)) {
      _popupSession = Object();
      _popupOpen = false;
      _confirmationToken = null;
      _suggestionTimer?.cancel();
      _lastSuggestionInput = null;
      _lastOptions = [];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isFullScreen = context.windowSizeClass.isCompact;
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _internalSearchController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSizes = context.appSizes;
    final owner = widget.viewModel;
    final searchController = _searchController;
    final session = _popupSession;
    final onSubmitted = widget.onSubmitted;
    final onSuggestionPressed = widget.onSuggestionPressed;
    final onBackPressed = widget.onBackPressed;
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
          searchController: searchController,
          viewBuilder: (suggestions) => _buildViewBuilder(
            suggestions,
            owner: owner,
            controller: searchController,
            session: session,
          ),
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
            onPressed: () {
              if (!_admits(owner, searchController, session)) return;
              searchController.closeView(null);
            },
          ),
          // Fires on every dismissal of the search view, including system
          // back, barrier dismissal, the leading close button, and
          // programmatic `closeView`.
          viewHintText: widget.hintText,
          viewOnOpen: () {
            if (!_owns(owner, searchController) ||
                !identical(session, _popupSession)) {
              return;
            }
            _popupOpen = true;
            _confirmationToken = null;
          },
          viewOnClose: () {
            if (!_owns(owner, searchController) ||
                !identical(session, _popupSession)) {
              return;
            }
            _popupOpen = false;
            if (!_closingConfirmation) _confirmationToken = null;
            _suggestionTimer?.cancel();
            _lastSuggestionInput = null;
            setState(() => _popupSession = Object());
            onBackPressed?.call();
          },
          viewOnSubmitted: (query) => _confirm(
            owner,
            searchController,
            session,
            query,
            () => onSubmitted?.call(query),
          ),
          suggestionsBuilder: (context, controller) {
            // The popup view route outlives this anchor State: it stays
            // alive during its exit transition and remains a listener on
            // the SearchController, so it can re-invoke this closure after
            // the host navigated away (goNamed) and unmounted the anchor.
            // Return the last cached result — a plain field read that
            // cannot throw — and skip all widget/context access.
            if (!mounted) return _lastHistory;

            // Capture owner references for popup callbacks.
            if (!_owns(owner, searchController) ||
                !identical(session, _popupSession)) {
              return _lastHistory;
            }
            final viewModel = owner;

            _admitSuggestions(viewModel, controller.text);

            if (controller.text.isEmpty) {
              // Inert fallback only. The popup's Recenti branch owns the
              // live history subscription, independently of text changes.
              return _lastHistory;
            }

            if (!SearchViewModel.isSearchQueryValid(controller.text)) {
              if (_lastOptions.isNotEmpty) _lastOptions = [];
              return _lastOptions;
            }

            return _lastOptions = <Widget>[
              ListenableBuilder(
                listenable: viewModel.loadSuggestions.results,
                builder: (context, _) {
                  if (!_owns(viewModel, controller) ||
                      !identical(session, _popupSession)) {
                    return const SizedBox.shrink();
                  }
                  final snapshot = viewModel.loadSuggestions.results.value;
                  if (snapshot.completed) {
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
                        _confirm(
                          viewModel,
                          controller,
                          session,
                          content.name,
                          () => onSuggestionPressed(content),
                        );
                      },
                    );
                  }

                  if (snapshot.hasFailure) {
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
    required BuildContext popupContext,
    required SearchViewModel viewModel,
    required SearchController controller,
    required Object session,
    List<String> texts = const [],
    bool showDeleteIcon = false,
  }) {
    // Cached chips can outlive their popup; each callback checks its session.

    return UnmodifiableListView(
      texts.map((e) {
        return RawChip(
          label: Text(e),
          onPressed: () {
            if (!_admits(viewModel, controller, session)) return;
            controller.text = e;
            if (!_admits(viewModel, controller, session)) return;
            viewModel.addToPastSearches(e);
          },
          deleteIcon: const Icon(Symbols.close),
          onDeleted: showDeleteIcon
              ? () {
                  if (!_admits(viewModel, controller, session)) return;
                  viewModel.removeFromPastSearches(e);
                }
              : null,
          backgroundColor: Theme.of(
            popupContext,
          ).colorScheme.surfaceContainerLow,
        );
      }),
    );
  }

  /// Lays out the suggestion list of the search view.
  Widget _buildViewBuilder(
    Iterable<Widget> suggestions, {
    required SearchViewModel owner,
    required SearchController controller,
    required Object session,
  }) {
    // The search view lives in its own popup route, which keeps rebuilding
    // `viewBuilder` on every animation tick while it fades out. If the anchor
    // has been unmounted (e.g. the host navigated away via goNamed right after
    // closeView), `State.context` would throw a null-check error. Return a
    // harmless widget for the remaining exit-transition frames.
    if (!mounted ||
        !_owns(owner, controller) ||
        !identical(session, _popupSession)) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    if (_searchController.text.isEmpty) {
      children
        ..addAll([
          const TextSectionDivider('Categorie'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CategoryContentWrap(
              chipBackgroundColor: context.colorScheme.surfaceContainerLow,
              onCategorySelected: (category) {
                if (!_admits(owner, controller, session)) return;
                controller.text = category.label;
                if (!_admits(owner, controller, session)) return;
                owner.addToPastSearches(category.label);
              },
            ),
          ),
        ])
        ..add(
          ListenableBuilder(
            listenable: owner,
            builder: (popupContext, _) {
              if (!mounted ||
                  !_owns(owner, controller) ||
                  !identical(session, _popupSession) ||
                  controller.text.isNotEmpty) {
                return const SizedBox.shrink();
              }
              _lastHistory = _buildChips(
                popupContext: popupContext,
                viewModel: owner,
                controller: controller,
                session: session,
                texts: owner.pastSearches,
                showDeleteIcon: true,
              );
              final loading = owner.pastSearchesState.value.isRunning;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TextSectionDivider('Recenti'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _lastHistory,
                    ),
                  ),
                  if (loading) const LinearProgressIndicator(),
                  if (owner.pastSearchesFailure != null)
                    const ListTile(
                      title: Text('Impossibile caricare la cronologia.'),
                    ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            if (!_admits(owner, controller, session)) return;
                            owner.requestPastSearchesRefresh();
                          },
                    child: const Text('Ricarica cronologia'),
                  ),
                ],
              );
            },
          ),
        );
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

  /// Debounces admission only; execution authority is revoked on every edit.
  void _admitSuggestions(SearchViewModel viewModel, String text) {
    if (_lastSuggestionInput == text) return;
    _lastSuggestionInput = text;
    _suggestionTimer?.cancel();
    viewModel.loadSuggestions.invalidate();
    if (!SearchViewModel.isSearchQueryValid(text)) {
      viewModel.loadSuggestions.run(text);
      return;
    }
    _suggestionTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (!identical(widget.viewModel, viewModel)) return;
      viewModel.loadSuggestions.run(text);
    });
  }
}
