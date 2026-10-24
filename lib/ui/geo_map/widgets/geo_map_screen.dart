import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_mode.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_selection_intent.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/components/animated_geo_map_search_bar.dart';
import 'package:moliseis/ui/geo_map/widgets/components/animated_map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_search_results.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/utils/debounceable.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result_command.dart';

/// Map presentation uses the model's sole semantic mode. Local selections do
/// not rewrite the URI; system Back remains owned by the route stack.
class GeoMapScreen extends StatefulWidget {
  const GeoMapScreen({
    required this.routeSelection,
    required this.viewModel,
    required this.searchViewModel,
    required this.weatherViewModel,
    super.key,
  });

  final GeoMapContentIdentity? routeSelection;
  final GeoMapViewModel viewModel;
  final SearchViewModel searchViewModel;

  /// Route-created owner, released on replacement or screen removal.
  final WeatherViewModel weatherViewModel;

  @override
  State<GeoMapScreen> createState() => _GeoMapScreenState();
}

class _GeoMapScreenState extends State<GeoMapScreen> {
  static const _initialCenter = LatLng(41.5575078, 14.6485406);
  final _mapController = MapController();
  final _searchController = SearchController();
  final _sheetController = DraggableScrollableController();
  final _showSearchBar = ValueNotifier<bool>(true);
  bool _mapReady = false;
  Object _effectToken = Object();
  GeoMapMode? _observedMode;
  ContentBase? _observedContent;
  Object? _consumedSelection;
  GeoMapSearchAdmission? _searchAdmission;
  late final Debounced<
    void,
    ({GeoMapViewModel owner, Object token, GeoMapMode mode})
  >
  _settle;

  LatLng get _liveCenter =>
      _mapReady ? _mapController.camera.center : _initialCenter;

  @override
  void initState() {
    super.initState();
    _settle = debounce(
      duration: const Duration(milliseconds: 1500),
      function: ([capture]) {
        if (capture != null &&
            _ownsEffect(capture.owner, capture.token, capture.mode) &&
            capture.mode is GeoMapExplore) {
          capture.owner.commitExploreAnchor(_liveCenter);
        }
        return Future<void>.value();
      },
    );
    _bindOwner();
    _applyRoute();
  }

  void _bindOwner() {
    widget.viewModel.addListener(_onModeChanged);
    widget.viewModel.selectContent.results.addListener(_onSelectionChanged);
    _onModeChanged();
  }

  void _detachOwner(GeoMapViewModel owner) {
    owner.removeListener(_onModeChanged);
    owner.selectContent.results.removeListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant GeoMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ownerChanged = !identical(oldWidget.viewModel, widget.viewModel);
    final searchChanged = !identical(
      oldWidget.searchViewModel,
      widget.searchViewModel,
    );
    if (ownerChanged) {
      _detachOwner(oldWidget.viewModel);
      oldWidget.viewModel.selectContent.invalidate();
      oldWidget.viewModel.loadNearContent.invalidate();
      _revokeEffects();
      _searchAdmission = null;
      _observedMode = null;
      _observedContent = null;
      _consumedSelection = null;
      _bindOwner();
    }
    if (!identical(oldWidget.weatherViewModel, widget.weatherViewModel)) {
      oldWidget.weatherViewModel.setTarget(null);
      oldWidget.weatherViewModel.dispose();
      _bindWeather();
    }
    if (searchChanged) {
      oldWidget.searchViewModel.loadResults.invalidate();
      _searchAdmission = null;
    }
    if (ownerChanged || oldWidget.routeSelection != widget.routeSelection) {
      _applyRoute();
    } else if (searchChanged && widget.viewModel.mode is GeoMapSearchResults) {
      final owner = widget.viewModel;
      final search = widget.searchViewModel;
      final mode = owner.mode as GeoMapSearchResults;
      final token = _effectToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_ownsEffect(owner, token, mode) ||
            !identical(widget.searchViewModel, search)) {
          return;
        }
        _onSearchSubmitted(mode.query);
      });
    }
  }

  @override
  void dispose() {
    _detachOwner(widget.viewModel);
    _revokeEffects();
    _searchAdmission = null;
    widget.searchViewModel.loadResults.invalidate();
    widget.weatherViewModel.setTarget(null);
    widget.weatherViewModel.dispose();
    _sheetController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _showSearchBar.dispose();
    super.dispose();
  }

  void _revokeEffects() {
    _effectToken = Object();
    _settle.cancel();
  }

  bool _ownsEffect(GeoMapViewModel owner, Object token, GeoMapMode mode) =>
      mounted &&
      !owner.isDisposed &&
      identical(widget.viewModel, owner) &&
      identical(_effectToken, token) &&
      identical(owner.mode, mode);

  void _applyRoute() {
    final owner = widget.viewModel;
    final identity = widget.routeSelection;
    // A newly initialized default owner already presents the correct surface.
    if (identity == null &&
        owner.mode is GeoMapExplore &&
        owner.resolvedContent == null &&
        owner.exploreAnchor == _liveCenter &&
        !owner.selectContent.isRunningSync.value) {
      return;
    }
    _revokeEffects();
    _searchAdmission = null;
    widget.searchViewModel.loadResults.invalidate();
    widget.weatherViewModel.setTarget(null);
    final mode = owner.prepareRouteAdmission(identity, _liveCenter);
    if (mode == null || !identical(owner.mode, mode)) return;
    _onModeChanged();
    final token = _effectToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ownsEffect(owner, token, mode) ||
          widget.routeSelection != identity) {
        return;
      }
      _searchController.clear();
      owner.admitPreparedRoute(mode);
    });
  }

  void _bindWeather() {
    final content = widget.viewModel.resolvedContent;
    widget.weatherViewModel.setTarget(
      content == null
          ? null
          : (
              id: content.remoteId,
              type: content is Event ? ContentType.event : ContentType.place,
              latitude: content.coordinates.latitude,
              longitude: content.coordinates.longitude,
            ),
    );
  }

  void _onModeChanged() {
    if (!mounted) return;
    final owner = widget.viewModel;
    final mode = owner.mode;
    final content = owner.resolvedContent;
    _bindWeather();
    if (!identical(_searchAdmission?.mode, mode)) _searchAdmission = null;
    if (mode is! GeoMapSearchResults) {
      widget.searchViewModel.loadResults.invalidate();
    }
    // Immediate command coordination may admit a different semantic intent.
    if (owner.isDisposed ||
        !identical(widget.viewModel, owner) ||
        !identical(owner.mode, mode) ||
        !identical(owner.resolvedContent, content)) {
      return;
    }
    if (identical(_observedMode, mode) &&
        identical(_observedContent, content)) {
      return;
    }
    _observedMode = mode;
    _observedContent = content;
    _revokeEffects();
    final token = _effectToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ownsEffect(owner, token, mode)) return;
      switch (mode) {
        case GeoMapExplore():
          unawaited(_animateBottomSheetTo(0.3));
        case GeoMapSearchResults():
          unawaited(_animateBottomSheetTo(1));
        case GeoMapPostDetail():
          if (content == null ||
              !identical(owner.resolvedContent, content) ||
              owner.selectContent.isRunningSync.value) {
            return;
          }
          _presentPost(owner, token, mode, content);
      }
    });
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    final owner = widget.viewModel;
    final mode = owner.mode;
    final snapshot = owner.selectContent.results.value;
    if (mode is! GeoMapPostDetail ||
        owner.resolvedContent != null ||
        owner.selectContent.isRunningSync.value ||
        snapshot.isRunning ||
        snapshot.idle ||
        identical(_consumedSelection, snapshot)) {
      return;
    }
    final matches = switch (snapshot.paramData) {
      EventSelection(:final id) =>
        mode.identity == (id: id, type: ContentType.event),
      PlaceSelection(:final id) =>
        mode.identity == (id: id, type: ContentType.place),
      _ => false,
    };
    if (!matches || snapshot.unexpectedError is AssertionError) return;
    if (snapshot.completed &&
        snapshot.paramData!.matchesPayload(snapshot.data?.getOrNull())) {
      return;
    }
    _consumedSelection = snapshot;
    final fallback = owner.fallbackToExplore(_liveCenter, snapshot);
    if (fallback == null ||
        !mounted ||
        !identical(widget.viewModel, owner) ||
        !identical(owner.mode, fallback) ||
        !identical(owner.selectContent.results.value, snapshot) ||
        owner.selectContent.isRunningSync.value) {
      return;
    }
    final token = _effectToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ownsEffect(owner, token, fallback) ||
          !identical(owner.selectContent.results.value, snapshot) ||
          owner.selectContent.isRunningSync.value) {
        return;
      }
      showSnackBar(
        context: context,
        textContent: 'Contenuto non trovato',
        type: SnackBarType.error,
      );
    });
  }

  void _presentPost(
    GeoMapViewModel owner,
    Object token,
    GeoMapMode mode,
    ContentBase content,
  ) {
    final screenHeight = MediaQuery.maybeSizeOf(context)?.height ?? 0;
    final topPadding = MediaQuery.maybeViewPaddingOf(context)?.top ?? 0;
    final offset = (screenHeight * 0.5 - topPadding) / -2;
    _settle.cancel();
    Future<void>.delayed(Duration.zero, () {
      if (!_ownsEffect(owner, token, mode) ||
          !_mapReady ||
          !identical(owner.resolvedContent, content) ||
          owner.selectContent.isRunningSync.value) {
        return;
      }
      _mapController.move(
        content.coordinates,
        16,
        offset: Offset(0, offset + 16),
      );
    });
    unawaited(_animateBottomSheetTo(0.5));
  }

  void _showContent(ContentBase content) {
    if (!mounted) return;
    _searchController.clear();
    widget.viewModel.showContent(content);
  }

  void _onSearchSubmitted(String query) {
    if (!mounted || !SearchViewModel.isSearchQueryValid(query)) return;
    final owner = widget.viewModel;
    final search = widget.searchViewModel;
    final excludedSnapshot = search.loadResults.results.value;
    final mode = owner.showSearchResults(query);
    if (!mounted ||
        mode == null ||
        !identical(widget.viewModel, owner) ||
        !identical(widget.searchViewModel, search) ||
        !identical(owner.mode, mode)) {
      return;
    }
    final admission = (
      searchOwner: search,
      mode: mode,
      excludedSnapshot: excludedSnapshot,
    );
    setState(() {
      _searchAdmission = admission;
    });
    search.loadResults.run(query);
    if (!mounted ||
        !identical(widget.viewModel, owner) ||
        !identical(widget.searchViewModel, search) ||
        !_isCurrentAdmission(admission) ||
        !identical(owner.mode, mode)) {
      return;
    }
    if (_searchController.isOpen) _searchController.closeView(query);
  }

  bool _isCurrentAdmission(GeoMapSearchAdmission? admission) =>
      admission != null &&
      _searchAdmission != null &&
      identical(_searchAdmission!.mode, admission.mode) &&
      identical(_searchAdmission!.searchOwner, admission.searchOwner) &&
      identical(_searchAdmission!.excludedSnapshot, admission.excludedSnapshot);

  bool _admitsSearch(
    GeoMapSearchAdmission? admission,
    GeoMapViewModel owner,
    SearchViewModel search,
  ) =>
      mounted &&
      identical(widget.viewModel, owner) &&
      identical(widget.searchViewModel, search) &&
      _isCurrentAdmission(admission) &&
      admitsGeoMapSearchSnapshot(admission, owner, search);

  void _closeTransientSheet() {
    if (!mounted) return;
    _searchController.clear();
    widget.viewModel.showExplore(_liveCenter);
  }

  Future<void> _animateBottomSheetTo(double size) {
    if (!_sheetController.isAttached) return Future<void>.value();
    return _sheetController.animateTo(
      size,
      duration: size < _sheetController.size
          ? Durations.short4
          : Durations.long2,
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.viewModel,
      widget.viewModel.loadMarkers.results,
    ]),
    builder: (context, _) {
      final owner = widget.viewModel;
      final search = widget.searchViewModel;
      final admission = _searchAdmission;
      final markerRequest = owner.markerRequest;
      final markerTerminal = owner.markerTerminal;
      final markerOutcome = owner.markerOutcome;
      bool ownsMarkers() =>
          mounted &&
          !owner.isDisposed &&
          identical(widget.viewModel, owner) &&
          identical(owner.markerRequest, markerRequest) &&
          identical(owner.markerTerminal, markerTerminal);
      return Scaffold(
        appBar: const CustomAppBar.hidden(),
        body: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            GeoMap(
              mapController: _mapController,
              initialCenter: _initialCenter,
              onMapReady: (_) {
                if (mounted) _mapReady = true;
              },
              children: <Widget>[
                if (markerOutcome != null)
                  MarkerLayer(
                    markers: [
                      for (final content in [
                        ...markerOutcome.events,
                        ...markerOutcome.places,
                      ])
                        generateMapMarker(
                          content,
                          onPressed: () {
                            if (ownsMarkers()) _showContent(content);
                          },
                        ),
                    ],
                  ),
              ],
              onPressed: (_, _) {
                if (!mounted || !_sheetController.isAttached) return;
                unawaited(
                  _animateBottomSheetTo(
                    _sheetController.size <= 0.01 ? 0.5 : 0.3,
                  ),
                );
              },
              onPositionChangeStart: (_) {
                if (!mounted) return;
                _settle.cancel();
                if (owner.mode is GeoMapExplore) {
                  unawaited(_animateBottomSheetTo(0.3));
                }
              },
              onPositionChangeEnd: (_) {
                if (!mounted || owner.mode is! GeoMapExplore) return;
                unawaited(
                  _settle((
                    owner: owner,
                    token: _effectToken,
                    mode: owner.mode,
                  )),
                );
              },
            ),
            AnimatedMapAttribution(controller: _sheetController),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.appSizes.bottomSheetMaxWidth,
                  ),
                  child: GeoMapBottomSheet(
                    controller: _sheetController,
                    onCloseButtonPressed: _closeTransientSheet,
                    onContentPressed: _showContent,
                    searchAdmission: admission,
                    onSearchResultPressed: (content) {
                      if (_admitsSearch(admission, owner, search)) {
                        _showContent(content);
                      }
                    },
                    onSearchRetryPressed: () {
                      if (_admitsSearch(admission, owner, search)) {
                        _onSearchSubmitted(admission!.mode.query);
                      }
                    },
                    onVerticalDragUpdate: (size) {
                      if (!mounted) return;
                      final show = size < (context.isLandscape ? 0.55 : 0.75);
                      if (_showSearchBar.value != show) {
                        _showSearchBar.value = show;
                      }
                    },
                    viewModel: owner,
                    searchViewModel: search,
                    weatherViewModel: widget.weatherViewModel,
                  ),
                ),
              ),
            ),
            AnimatedGeoMapSearchBar(
              searchController: _searchController,
              animation: _showSearchBar,
              onSubmitted: _onSearchSubmitted,
              onBackPressed: () {
                if (mounted) _searchController.clear();
              },
              onSuggestionPressed: (content) =>
                  _onSearchSubmitted(content.name),
              viewModel: search,
              trailing: <Widget>[
                CategoryContentAndTypeSelection(
                  key: ObjectKey(owner),
                  selectedCategories: owner.selectedCategories,
                  selectedTypes: owner.selectedTypes,
                  onCategorySelectionChanged: owner.setSelectedCategories,
                  onTypeSelectionChanged: owner.setSelectedTypes,
                ),
              ],
            ),
            if (owner.markerStatus != GeoMapMarkerStatus.successData)
              Positioned(
                top: 128,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      key: const ValueKey('geo-map-marker-status'),
                      color: context.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: switch (owner.markerStatus) {
                          GeoMapMarkerStatus.loading =>
                            const CircularProgressIndicator(
                              semanticsLabel:
                                  'Caricamento contenuti della mappa',
                            ),
                          GeoMapMarkerStatus.successEmpty => const Text(
                            'Nessun contenuto per i filtri selezionati',
                          ),
                          GeoMapMarkerStatus.failure => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Si è verificato un problema, riprova.',
                              ),
                              TextButton(
                                onPressed: () {
                                  if (ownsMarkers()) owner.retryMarkers();
                                },
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                          GeoMapMarkerStatus.successData =>
                            const SizedBox.shrink(),
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
      );
    },
  );
}
