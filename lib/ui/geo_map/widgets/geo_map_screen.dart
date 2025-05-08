import 'dart:collection' show UnmodifiableListView;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/geo_map/geo_map_state.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/pad.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';
import 'package:moliseis/utils/debounceable.dart';

class GeoMapScreen extends StatefulWidget {
  const GeoMapScreen({
    super.key,
    required this.mapState,
    required this.viewModel,
  });

  final GeoMapState mapState;
  final GeoMapViewModel viewModel;

  @override
  State<GeoMapScreen> createState() => _GeoMapScreenState();
}

class _GeoMapScreenState extends State<GeoMapScreen> {
  /// The attraction Id.
  ///
  /// When [_attractionId] is equal to 0, [GeoMapBottomSheet] will show a list of
  /// attractions near the [_currentCenter], otherwise the details of the
  /// selected attraction will be shown instead.
  int _attractionId = 0;

  /// The current map center.
  ///
  /// Defaults to somewhere near Campobasso.
  LatLng _currentCenter = const LatLng(41.5575078, 14.6485406);

  late final Debounceable1<bool> _debouncedUpdate;

  final _mapController = MapController();

  /// Caches this [Future].
  late final Future<List<Attraction>> _mapMarkersFuture;

  final _mapOpacity = ValueNotifier<double>(0);

  ///
  final _moveMapAttribution = ValueNotifier<double>(0.35);

  /// Whether to schedule a callback on next frame build or not.
  ///
  /// The callback will be executed exactly once, and will be rescheduled on a
  /// widget configuration change.
  ///
  /// See also:
  ///
  ///  * [didUpdateWidget]
  bool _scheduleCallbackOnNextFrame = true;

  final _searchController = SearchController();
  final _sheetController = DraggableScrollableController();

  /// Whether the search bar is currently visible or not.
  final _showSearchBar = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    if (widget.mapState.hasValidCoords && widget.mapState.hasValidId) {
      _changeMapState(
        latitude: widget.mapState.latitude,
        longitude: widget.mapState.longitude,
        attractionId: widget.mapState.attractionId,
      );
    }

    _debouncedUpdate = debounce1<bool>(
      duration: const Duration(milliseconds: 1500),
      function: _update,
    );

    _mapMarkersFuture = widget.viewModel.getAllAttractions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_sheetController.isAttached) {
      _clampMapAttributionPosition();
    }
  }

  @override
  void didUpdateWidget(covariant GeoMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.mapState.hasValidCoords && widget.mapState.hasValidId) {
      _changeMapState(
        latitude: widget.mapState.latitude,
        longitude: widget.mapState.longitude,
        attractionId: widget.mapState.attractionId,
      );

      /// Schedules a callback on next frame build.
      _scheduleCallbackOnNextFrame = true;
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _update() async => true;

  @override
  Widget build(BuildContext context) {
    /// Guards the addPostFrameCallback() from running multiple times
    /// when it is not needed, e.g. when the app Brightness changes and
    /// widgets are rebuilt.
    if (_scheduleCallbackOnNextFrame) {
      /// Schedules a callback to be fired once when the build phase of this
      /// widget has ended.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        /// Animates the bottom sheet up to show an attraction's details if
        /// the user has requested to view in this screen or somewhere else.
        if (_attractionId != 0) {
          _animateStateChange(
            _currentCenter.latitude,
            _currentCenter.longitude,
            _attractionId,
          );
        }
      });
    }

    final appSearchBar = CustomSearchAnchor(
      controller: _searchController,
      onSubmitted: (text) {
        // TODO (xmattjus): show search results in a new view in the bottom sheet.
      },
      onBackPressed: () {
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
      },
      elevation: 1.0,
      onSuggestionPressed: (attractionId) async {
        _searchController.clear();
        _searchController.closeView(null);

        final attraction = await widget.viewModel.getAttractionById(
          attractionId,
        );

        _animateStateChange(
          attraction.coordinates[0],
          attraction.coordinates[1],
          attraction.id,
        );
      },
    );

    final map = GeoMap(
      mapController: _mapController,
      initialCenter: _currentCenter,
      children: <Widget>[
        FutureBuilt<List<Attraction>>(
          _mapMarkersFuture,
          onSuccess: (data) {
            return MarkerLayer(
              markers: UnmodifiableListView<Marker>(
                data.map<Marker>((Attraction attraction) {
                  return generateMapMarker(
                    attraction,
                    onPressed: () {
                      _animateStateChange(
                        attraction.coordinates[0],
                        attraction.coordinates[1],
                        attraction.id,
                      );
                    },
                  );
                }),
              ),
            );
          },
          onError: (error) {
            return const SizedBox();
          },
        ),
      ],
      onPressed: (tapPosition, point) {
        /// Shows the bottom sheet if it's currently not visible.
        if (_sheetController.size <= 0.01) {
          _showBottomSheet();
        } else {
          _hideBottomSheet();
        }
      },
      onPositionChangeStart: (center) => _hideBottomSheet(),
      onPositionChangeEnd: (center) async {
        final update = await _debouncedUpdate();

        if (update != null && update) {
          setState(() {
            _currentCenter = center;
          });
        }
      },
    );

    final bottomSheet = SafeArea(
      child: GeoMapBottomSheet(
        controller: _sheetController,
        attractionId: _attractionId,
        currentCenter: _currentCenter,
        onNearAttractionTap: (id) async {
          final attraction = await widget.viewModel.getAttractionById(id);

          _animateStateChange(
            attraction.coordinates[0],
            attraction.coordinates[1],
            attraction.id,
          );
        },
        onCloseButtonTap: () {
          setState(() {
            _attractionId = 0;
            _currentCenter = _mapController.camera.center;
          });
          _hideBottomSheet();
        },
        onVerticalDragUpdate: (size) {
          /// Hides the top search bar if the bottom sheet is been dragged to
          /// the top of the screen.
          _showSearchBar.value = size < 0.75;

          _mapOpacity.value = size < 0.75 ? 0 : 0.32;

          _clampMapAttributionPosition();
        },
      ),
    );

    final mapAttribution = SafeArea(
      child: AnimatedBuilder(
        animation: _moveMapAttribution,
        builder: (context, child) {
          return AnimatedSlide(
            offset: Offset(0, _moveMapAttribution.value * -1.0),
            duration: Duration.zero,
            child: child,
          );
        },
        child: const Pad(v: 8.0, child: GeoMapAttribution()),
      ),
    );

    final opacityLayer = IgnorePointer(
      child: AnimatedBuilder(
        animation: _mapOpacity,
        builder: (context, child) {
          final scrim = Theme.of(context).colorScheme.scrim;
          return ColoredBox(
            color: scrim.withValues(alpha: _mapOpacity.value),
            child: child,
          );
        },
        child: const SizedBox.expand(),
      ),
    );

    final searchBar = SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: _showSearchBar,
          builder: (context, child) {
            return AnimatedSlide(
              offset: Offset(0, _showSearchBar.value ? 0 : -2.0),
              curve:
                  _showSearchBar.value
                      ? Curves.easeInOutCubicEmphasized
                      : Easing.emphasizedDecelerate,
              duration:
                  _showSearchBar.value
                      ? Durations
                          .medium2 // To visible
                      : Durations.short3, // To not visible
              child: child,
            );
          },
          child: appSearchBar,
        ),
      ),
    );

    return PopScope(
      canPop: _attractionId == 0,
      onPopInvokedWithResult: (didPop, result) {
        setState(() => _attractionId = 0);

        _hideBottomSheet();
      },
      child: Scaffold(
        appBar: const CustomAppBar.hidden(),
        body: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            map,
            mapAttribution,
            opacityLayer,
            bottomSheet,
            searchBar,
          ],
        ),
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
      ),
    );
  }

  /// Animates various UI elements on requested widget rebuilds.
  void _animateStateChange(
    double latitude,
    double longitude,
    int attractionId,
  ) {
    final newCenter = LatLng(latitude, longitude);

    /// Updates the internal state.
    setState(() {
      _changeMapState(
        latitude: latitude,
        longitude: longitude,
        attractionId: attractionId,
      );

      /// Prevents the scheduling of this callback on next frame builds.
      ///
      /// [didUpdateWidget] will resets this value to false.
      _scheduleCallbackOnNextFrame = false;
    });

    /// Centers the pressed map marker to the first half of the screen since the
    /// second half will be covered by the bottom sheet.
    final x = MediaQuery.sizeOf(context).height / 1.5;

    // TODO(xmattjus): find out why the map does not load without a fake delay, https://github.com/fleaflet/flutter_map/issues/1813.
    Future.delayed(Duration.zero, () {
      _mapController.move(newCenter, 20, offset: Offset(0, -x));
    });

    _showBottomSheet();
  }

  void _changeMapState({
    required double latitude,
    required double longitude,
    required int attractionId,
  }) {
    _attractionId = attractionId;
    _currentCenter = LatLng(latitude, longitude);
  }

  /// Clamps the [GeoMapAttribution] movement on the X-axis to prevent its
  /// disappearing when the bottom sheet is completely closed.
  void _clampMapAttributionPosition() =>
      _moveMapAttribution.value = clampDouble(_sheetController.size, 0, 0.5);

  /// Animates the bottom sheet size to be approx. 1/3 the screen height.
  Future<void> _hideBottomSheet() => _sheetController.animateTo(
    0.3,
    duration: Durations.short4,
    curve: Curves.easeInOutCubicEmphasized,
  );

  /// Animates the bottom sheet size to be half the screen height.
  Future<void> _showBottomSheet() => _sheetController.animateTo(
    0.5,
    duration: Durations.long2,
    curve: Curves.easeInOutCubicEmphasized,
  );
}
