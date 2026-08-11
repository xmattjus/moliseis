import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart';
import 'package:moliseis/ui/geo_map/widgets/components/animated_map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/utils/debounceable.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Interactive map that shows nearby content and search results in a bottom
/// sheet.
///
/// The initial selection, when the location carries one, is identified by
/// [initialContentId] and [initialContentType] and resolved through the
/// [GeoMapViewModel] commands. A location without these parameters renders the
/// default map. A content identity that resolves to no repository item keeps
/// the default map and shows a snack bar, so the map never crashes on a stale
/// or malformed deep link.
///
/// Selected content and search results are widget-local state, dismissed only
/// by the explicit close controls in the sheet. System back is not
/// intercepted: it follows the route stack and never resets the map's
/// transient state.
class GeoMapScreen extends StatefulWidget {
  const GeoMapScreen({
    super.key,
    required this.initialContentId,
    required this.initialContentType,
    required this.viewModel,
    required this.searchViewModel,
    required this.weatherViewModel,
  });

  /// The content id selected by the current location, or null for the
  /// default map.
  final int? initialContentId;

  /// The content type of the [initialContentId] selection, or null when the
  /// location does not request an initial selection.
  final ContentType? initialContentType;

  final GeoMapViewModel viewModel;
  final SearchViewModel searchViewModel;
  final WeatherViewModel weatherViewModel;

  @override
  State<GeoMapScreen> createState() => _GeoMapScreenState();
}

class _GeoMapScreenState extends State<GeoMapScreen> {
  ContentBase? _selectedContent;

  /// The current map center.
  ///
  /// Initially set to somewhere near Campobasso.
  LatLng _currentCenter = const LatLng(41.5575078, 14.6485406);

  late final Debounceable<bool, void> _debouncedUpdate;

  final _mapController = MapController();

  /// The opacity of the layer shown on top of the map when the bottom sheet
  /// is vertically dragged above a certain threshold.
  final _scrimOpacity = ValueNotifier<double>(0);

  /// Whether to schedule a callback on next frame build or not.
  ///
  /// The callback will be executed exactly once, and will be rescheduled on a
  /// widget configuration change.
  ///
  /// See also:
  ///
  ///  * [didUpdateWidget]
  bool _scheduleCallbackOnNextFrame = false;

  final _searchController = SearchController();
  final _sheetController = DraggableScrollableController();

  /// Whether the search bar is currently visible or not.
  final _showSearchBar = ValueNotifier<bool>(true);

  String _searchQuery = '';

  /// The content identity requested by the current location while it is being
  /// resolved, or null when no initial selection is in flight.
  ///
  /// The identity is cleared with the terminal selection state, so command
  /// listeners only react to the requested selection and never to selections
  /// made from map markers or search results.
  ({int id, ContentType type})? _pendingSelection;

  /// Maximum number of times the resolution listener retries the requested
  /// identity after a successful but mismatched command completion.
  ///
  /// A single retry is enough to recover from an `execute()` silently dropped
  /// by `Command._execute` while a previous execution was still running
  /// (rapid deep-link navigation). A persistent mismatch — the repository
  /// returning content for a different id on success — becomes terminal after
  /// this budget, mirroring the no-match error branch.
  static const int _maxResolutionRetries = 1;

  /// Current retry count for the resolution of [_pendingSelection].
  ///
  /// Reset to zero whenever a new request is issued or the resolution reaches
  /// a terminal state (match, error, or retry budget exhausted).
  int _resolutionRetries = 0;

  @override
  void initState() {
    super.initState();

    widget.viewModel.showEvent.addListener(_onSelectionResolutionChanged);
    widget.viewModel.showPlace.addListener(_onSelectionResolutionChanged);
    _resolveRequestedSelection();

    _debouncedUpdate = debounce<bool, void>(
      duration: const Duration(milliseconds: 1500),
      function: ([_]) => Future.value(true),
    ).call;
  }

  @override
  void didUpdateWidget(covariant GeoMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The route builder creates a fresh view model on every navigation, so
    // the resolution listeners must follow the current widget's commands.
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.showEvent.removeListener(
        _onSelectionResolutionChanged,
      );
      oldWidget.viewModel.showPlace.removeListener(
        _onSelectionResolutionChanged,
      );
      widget.viewModel.showEvent.addListener(_onSelectionResolutionChanged);
      widget.viewModel.showPlace.addListener(_onSelectionResolutionChanged);
    }

    if (widget.initialContentId != null && widget.initialContentType != null) {
      _resolveRequestedSelection();
    } else {
      // A location without content identity is the default map: abandon any
      // in-flight resolution and drop the previous selection. The sheet
      // falls back to the explore modal instead of a stale post skeleton.
      _pendingSelection = null;
      _resolutionRetries = 0;
      _scheduleCallbackOnNextFrame = false;
      _selectedContent = null;
      _searchQuery = '';
      _searchController.text = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.initialContentId != null ||
            widget.initialContentType != null) {
          return;
        }

        unawaited(_animateBottomSheetTo(0.3));
      });
    }
  }

  @override
  void dispose() {
    widget.viewModel.showEvent.removeListener(_onSelectionResolutionChanged);
    widget.viewModel.showPlace.removeListener(_onSelectionResolutionChanged);
    _sheetController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Starts resolving the content identity requested by the current location,
  /// or abandons any in-flight resolution when the identity is absent.
  void _resolveRequestedSelection() {
    final id = widget.initialContentId;
    final type = widget.initialContentType;
    final request = id != null && type != null ? (id: id, type: type) : null;

    _pendingSelection = request;
    _resolutionRetries = 0;
    if (request == null) return;

    unawaited(
      request.type == ContentType.event
          ? widget.viewModel.showEvent.execute(request.id)
          : widget.viewModel.showPlace.execute(request.id),
    );
  }

  /// Applies the requested initial selection once the corresponding command
  /// resolves, or falls back to the default map with a snack bar when the
  /// repository has no matching item.
  void _onSelectionResolutionChanged() {
    final request = _pendingSelection;
    if (request == null) return;

    final selected = widget.viewModel.selectedContent;
    if (selected != null && _matches(request, selected)) {
      setState(() {
        _pendingSelection = null;
        _resolutionRetries = 0;
        _selectedContent = selected;
        _currentCenter = selected.coordinates;
        _searchQuery = '';
        _searchController.text = '';
      });
      _scheduleCallbackOnNextFrame = true;
      return;
    }

    final command = request.type == ContentType.event
        ? widget.viewModel.showEvent
        : widget.viewModel.showPlace;
    if (command.running) return;

    if (command.error) {
      _terminateResolutionWithFeedback();
      return;
    }

    // The command completed with a different selection. The legitimate case
    // is a superseded request that Command._execute silently dropped while a
    // previous execution was still running (rapid deep-link navigation), so
    // the requested identity is retried on the current view model. A
    // persistent mismatch — the repository returning content for a different
    // id on success (stale cache, repo bug) — is bounded by
    // [_maxResolutionRetries] and becomes terminal once the budget is
    // exhausted, mirroring the no-match error branch.
    if (_resolutionRetries >= _maxResolutionRetries) {
      _terminateResolutionWithFeedback();
      return;
    }

    _resolutionRetries += 1;
    unawaited(
      request.type == ContentType.event
          ? widget.viewModel.showEvent.execute(request.id)
          : widget.viewModel.showPlace.execute(request.id),
    );
  }

  /// Clears the in-flight resolution and the local selection state, and
  /// notifies the user that the requested content could not be shown.
  ///
  /// Used both when the command completes with an error and when the retry
  /// budget for persistent selection mismatches is exhausted.
  void _terminateResolutionWithFeedback() {
    setState(() {
      _pendingSelection = null;
      _resolutionRetries = 0;
      _selectedContent = null;
      _searchQuery = '';
      _searchController.text = '';
    });
    showSnackBar(
      context: context,
      textContent: 'Contenuto non trovato',
      type: SnackBarType.error,
    );
  }

  /// Returns true when [content] matches the requested [request] identity.
  bool _matches(({int id, ContentType type}) request, ContentBase content) {
    final type = content is Event ? ContentType.event : ContentType.place;
    return content.remoteId == request.id && type == request.type;
  }

  @override
  Widget build(BuildContext context) {
    // Guards the addPostFrameCallback() from running multiple times
    // when it is not needed, e.g. when the app Brightness changes and
    // widgets are rebuilt.
    if (_scheduleCallbackOnNextFrame) {
      final selectedContent = _selectedContent;
      _scheduleCallbackOnNextFrame = false;

      // Schedules a callback to be fired once when the build phase of this
      // widget has ended.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            selectedContent == null ||
            !identical(_selectedContent, selectedContent)) {
          return;
        }

        final requestedType = selectedContent is Event
            ? ContentType.event
            : ContentType.place;
        if (widget.initialContentId != selectedContent.remoteId ||
            widget.initialContentType != requestedType) {
          return;
        }

        // Animates the bottom sheet up to show the content's post.
        _animateStateChange(coordinates: selectedContent.coordinates);
      });
    }

    final map = GeoMap(
      mapController: _mapController,
      initialCenter: _currentCenter,
      children: <Widget>[
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            widget.viewModel.loadEvents,
            widget.viewModel.loadPlaces,
          ]),
          builder: (_, _) {
            if (widget.viewModel.loadEvents.completed &&
                widget.viewModel.loadPlaces.completed) {
              return MarkerLayer(
                markers: <Marker>[
                  ...UnmodifiableListView<Marker>(
                    widget.viewModel.allEvents.map<Marker>(
                      (content) => generateMapMarker(
                        content,
                        onPressed: () {
                          _animateStateChange(
                            coordinates: content.coordinates,
                            content: content,
                          );
                        },
                      ),
                    ),
                  ),
                  ...UnmodifiableListView<Marker>(
                    widget.viewModel.allPlaces.map<Marker>(
                      (content) => generateMapMarker(
                        content,
                        onPressed: () {
                          _animateStateChange(
                            coordinates: content.coordinates,
                            content: content,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            return const EmptyBox();
          },
        ),
      ],
      onPressed: (_, _) {
        /// Shows the bottom sheet if it's currently not visible.
        if (_sheetController.size <= 0.01) {
          unawaited(_animateBottomSheetTo(0.5));
        } else {
          unawaited(_animateBottomSheetTo(0.3));
        }
      },
      onPositionChangeStart: (_) => _animateBottomSheetTo(0.3),
      onPositionChangeEnd: (center) async {
        final update = await _debouncedUpdate();

        if (mounted && update != null && update) {
          setState(() {
            _currentCenter = center;
          });
        }
      },
    );

    final bottomSheet = SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.appSizes.bottomSheetMaxWidth,
          ),
          child: GeoMapBottomSheet(
            content: _selectedContent,
            isResolvingRequestedSelection: _pendingSelection != null,
            controller: _sheetController,
            currentCenter: _currentCenter,
            onCloseButtonPressed: _closeTransientSheet,
            onContentPressed: (content) {
              _searchQuery = '';
              _searchController.text = '';

              _animateStateChange(
                coordinates: content.coordinates,
                content: content,
              );
            },
            onVerticalDragUpdate: (size) {
              /// The maximum bottom sheet size above which the search bar will
              /// be animated out of the screen.
              final maxBottomSheetSize = context.isLandscape ? 0.55 : 0.75;

              /// Hides the search bar if the bottom sheet is being dragged
              /// above the maximum bottom sheet size.
              ///
              /// Each ValueNotifier is set exactly once per state change.
              if (size < maxBottomSheetSize && !_showSearchBar.value) {
                _showSearchBar.value = true;
              } else if (size > maxBottomSheetSize && _showSearchBar.value) {
                _showSearchBar.value = false;
              }

              if (size < maxBottomSheetSize && _scrimOpacity.value != 0) {
                _scrimOpacity.value = 0;
              } else if (size > maxBottomSheetSize &&
                  _scrimOpacity.value != 0.32) {
                _scrimOpacity.value = 0.32;
              }
            },
            searchQuery: _searchQuery,
            viewModel: widget.viewModel,
            searchViewModel: widget.searchViewModel,
            weatherViewModel: widget.weatherViewModel,
          ),
        ),
      ),
    );

    /*
    final scrimColor = Theme.of(context).colorScheme.scrim.withAlpha(82);

    final scrimLayer = IgnorePointer(
      child: AnimatedBuilder(
        animation: _scrimOpacity,
        builder: (_, child) {
          return _scrimOpacity.value > 0 ? child! : const EmptyBox();
        },
        child: ColoredBox(color: scrimColor, child: const SizedBox.expand()),
      ),
    );
    */

    return Scaffold(
      appBar: const CustomAppBar.hidden(),
      body: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          map,
          AnimatedMapAttribution(controller: _sheetController),
          // scrimLayer,
          bottomSheet,
          AnimatedGeoMapSearchBar(
            searchController: _searchController,
            animation: _showSearchBar,
            onSubmitted: _onSearchSubmitted,
            onBackPressed: _onSeachBackPressed,
            onSuggestionPressed: (content) => _onSearchSubmitted(content.name),
            viewModel: widget.searchViewModel,
            trailing: <Widget>[
              CategoryContentAndTypeSelection(
                selectedCategories: widget.viewModel.selectedCategories,
                selectedTypes: widget.viewModel.selectedTypes,
                onCategorySelectionChanged: _onCategorySelectionChanged,
                onTypeSelectionChanged: _onTypeSelectionChanged,
              ),
            ],
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
    );
  }

  void _onSearchSubmitted(String text) {
    if (_searchController.isOpen) {
      _searchController.closeView(text);
    }

    unawaited(widget.searchViewModel.loadResults.execute(text));

    setState(() {
      _selectedContent = null;
      _searchQuery = text;
    });

    unawaited(_animateBottomSheetTo(1));
  }

  /// Clears the search input once the search view has been dismissed.
  ///
  /// Invoked through `AppSearchAnchor.viewOnClose`, so the popup route is
  /// already popped and [SearchController.closeView] must not be called again
  /// (it would pop the route below).
  void _onSeachBackPressed() {
    _searchController.clear();
  }

  void _onCategorySelectionChanged(Set<ContentCategory> selectedCategories) =>
      widget.viewModel.setSelectedCategories.execute(selectedCategories);

  void _onTypeSelectionChanged(Set<ContentType> selectedTypes) =>
      widget.viewModel.setSelectedTypes.execute(selectedTypes);

  /// Animates various UI elements on requested widget rebuilds.
  void _animateStateChange({
    required LatLng coordinates,
    ContentBase? content,
  }) {
    setState(() {
      if (content != null) {
        _selectedContent = content;
      }

      _currentCenter = coordinates;
    });

    final screenHeight = MediaQuery.maybeSizeOf(context)?.height ?? 0;

    // Calculates the offset the new center will have. The map marker should be
    // positioned at an equal distance between the system status bar, if any,
    // and the "bottom window chrome" (e.g. the bottom sheet height).
    final topViewPadding = MediaQuery.maybeViewPaddingOf(context)?.top ?? 0;

    final bottomChromeHeight = screenHeight * 0.5;

    // The offset is negative because the new center will be moved "up" on the
    // screen.
    final offset = (bottomChromeHeight - topViewPadding) / -2;

    // TODO(xmattjus): find out why the map does not load without a fake delay,
    //  https://github.com/fleaflet/flutter_map/issues/1813.
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      _mapController.move(_currentCenter, 16, offset: Offset(0, offset + 16.0));
    });

    unawaited(_animateBottomSheetTo(0.5));
  }

  /// Animates the attached sheet from its current size to the given [size], a
  /// fractional value of the parent container's height.
  Future<void> _animateBottomSheetTo(double size) {
    if (!_sheetController.isAttached) return Future<void>.value();

    final currentSize = _sheetController.size;
    final isMinimizing = size < currentSize;
    return _sheetController.animateTo(
      size,
      duration: isMinimizing ? Durations.short4 : Durations.long2,
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  /// Clears selected content, the search query, and controller text, and
  /// animates the sheet back to its default extent.
  void _closeTransientSheet() {
    setState(() {
      _currentCenter = _mapController.camera.center;
      _selectedContent = null;
      _searchController.text = '';
      _searchQuery = '';
    });
    unawaited(_animateBottomSheetTo(0.3));
  }
}
