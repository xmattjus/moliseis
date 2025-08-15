import 'dart:collection' show UnmodifiableListView;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/category/widgets/category_selection_list.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_attribution.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_marker.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';
import 'package:moliseis/utils/debounceable.dart';

class GeoMapScreen extends StatefulWidget {
  const GeoMapScreen({
    super.key,
    required this.contentExtra,
    required this.viewModel,
    required this.searchViewModel,
  });

  final ContentBase? contentExtra;
  final GeoMapViewModel viewModel;
  final SearchViewModel searchViewModel;

  @override
  State<GeoMapScreen> createState() => _GeoMapScreenState();
}

class _GeoMapScreenState extends State<GeoMapScreen> {
  ContentBase? _selectedContent;

  /// The current map center.
  ///
  /// Initially set to somewhere near Campobasso.
  LatLng _currentCenter = const LatLng(41.5575078, 14.6485406);

  late final Debounceable1<bool> _debouncedUpdate;

  final _mapController = MapController();

  /// The opacity of the layer shown on top of the map when the bottom sheet
  /// is vertically dragged above a certain threshold.
  final _scrimOpacity = ValueNotifier<double>(0);

  final _moveMapAttribution = ValueNotifier<double>(0.35);

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

  @override
  void initState() {
    super.initState();

    _sheetController.addListener(_bottomSheetListener);

    if (widget.contentExtra != null) {
      _selectedContent = widget.contentExtra;
      _currentCenter = LatLng(
        widget.contentExtra!.coordinates[0],
        widget.contentExtra!.coordinates[1],
      );
    }

    _debouncedUpdate = debounce1<bool>(
      duration: const Duration(milliseconds: 1500),
      function: () => Future.value(true),
    );
  }

  @override
  void didUpdateWidget(covariant GeoMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.contentExtra != null) {
      _selectedContent = widget.contentExtra;
      _currentCenter = LatLng(
        widget.contentExtra!.coordinates[0],
        widget.contentExtra!.coordinates[1],
      );

      _searchQuery = '';
      _searchController.text = '';

      // Schedules a callback on next frame build to animate the bottom sheet.
      _scheduleCallbackOnNextFrame = true;
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_bottomSheetListener);
    _sheetController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guards the addPostFrameCallback() from running multiple times
    // when it is not needed, e.g. when the app Brightness changes and
    // widgets are rebuilt.
    if (_scheduleCallbackOnNextFrame) {
      // Schedules a callback to be fired once when the build phase of this
      // widget has ended.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Animates the bottom sheet up to show the content's details.
        _animateStateChange(
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
        );

        // Prevents the scheduling of this callback on next frame builds.
        _scheduleCallbackOnNextFrame = false;
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
                            latitude: content.coordinates[0],
                            longitude: content.coordinates[1],
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
                            latitude: content.coordinates[0],
                            longitude: content.coordinates[1],
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
          _animateBottomSheetTo(0.5);
        } else {
          _animateBottomSheetTo(0.3);
        }
      },
      onPositionChangeStart: (_) => _animateBottomSheetTo(0.3),
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
        content: _selectedContent,
        controller: _sheetController,
        currentCenter: _currentCenter,
        onCloseButtonPressed: () {
          setState(() {
            _selectedContent = null;
            _currentCenter = _mapController.camera.center;
            _searchQuery = '';
            _searchController.text = '';
          });

          _animateBottomSheetTo(0.3);
        },
        onContentPressed: (content) {
          _searchQuery = '';
          _searchController.text = '';

          _animateStateChange(
            latitude: content.coordinates[0],
            longitude: content.coordinates[1],
            content: content,
          );
        },
        onVerticalDragUpdate: (size) {
          /// The maximum bottom sheet size above which the search bar will
          /// be animated out of the screen.
          const maxBottomSheetSize = 0.75;

          /// Hides the search bar if the bottom sheet is being dragged above
          /// the maximum bottom sheet size.
          ///
          /// Each ValueNotifier is set exactly once per state change.
          if (size < maxBottomSheetSize && !_showSearchBar.value) {
            _showSearchBar.value = true;
          } else if (size > maxBottomSheetSize && _showSearchBar.value) {
            _showSearchBar.value = false;
          }

          if (size < maxBottomSheetSize && _scrimOpacity.value != 0) {
            _scrimOpacity.value = 0;
          } else if (size > maxBottomSheetSize && _scrimOpacity.value != 0.32) {
            _scrimOpacity.value = 0.32;
          }
        },
        searchQuery: _searchQuery,
        viewModel: widget.viewModel,
        searchViewModel: widget.searchViewModel,
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
        child: const Padding(
          padding: EdgeInsetsDirectional.symmetric(vertical: 8.0),
          child: GeoMapAttribution(),
        ),
      ),
    );

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

    final appSearchBar = CustomSearchAnchor(
      controller: _searchController,
      onSubmitted: (text) {
        setState(() {
          _searchQuery = text;
        });

        _animateBottomSheetTo(1.0);
      },
      onBackPressed: () {
        final wasSearchViewOpen = _searchController.isOpen;

        if (wasSearchViewOpen) {
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
      onSuggestionPressed: (ContentBase content) {
        _searchController.closeView(content.name);

        setState(() {
          _searchQuery = content.name;
        });

        _animateBottomSheetTo(1.0);
      },
      viewModel: widget.searchViewModel,
    );

    final searchBar = SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: _showSearchBar,
          builder: (_, child) => AnimatedSlide(
            offset: Offset(0, _showSearchBar.value ? 0 : -2.0),
            curve: _showSearchBar.value
                ? Curves.easeInOutCubicEmphasized
                : Easing.emphasizedDecelerate,
            duration: _showSearchBar.value
                ? Durations.medium2
                : Durations.short3,
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                appSearchBar,
                CategorySelectionList(
                  onCategoriesSelectionChanged: (selectedCategories) {
                    widget.viewModel.setSelectedCategories.execute(
                      selectedCategories,
                    );
                  },
                  onTypesSelectionChanged: (selectedTypes) {
                    widget.viewModel.setSelectedTypes.execute(selectedTypes);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: _selectedContent == null && _searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        setState(() {
          _selectedContent = null;
          _searchController.text = '';
          _searchQuery = '';
        });

        _animateBottomSheetTo(0.3);
      },
      child: Scaffold(
        appBar: const CustomAppBar.hidden(),
        body: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            map,
            mapAttribution,
            scrimLayer,
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
  void _animateStateChange({
    required double latitude,
    required double longitude,
    ContentBase? content,
  }) {
    setState(() {
      if (content != null) {
        _selectedContent = content;
      }

      _currentCenter = LatLng(latitude, longitude);
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

    // TODO(xmattjus): find out why the map does not load without a fake delay, https://github.com/fleaflet/flutter_map/issues/1813.
    Future.delayed(Duration.zero, () {
      _mapController.move(_currentCenter, 16, offset: Offset(0, offset + 16.0));
    });

    _animateBottomSheetTo(0.5);
  }

  /// Listens to the bottom sheet controller movement.
  void _bottomSheetListener() {
    /// Clamps the [GeoMapAttribution] movement on the X-axis to prevent its
    /// disappearing when the bottom sheet is completely closed.
    // FIXME: setState() or markNeedsBuild() called during build.
    Future.delayed(Duration.zero, () {
      _moveMapAttribution.value = clampDouble(_sheetController.size, 0, 0.5);
    });
  }

  /// Animates the attached sheet from its current size to the given [size], a
  /// fractional value of the parent container's height.
  Future<void> _animateBottomSheetTo(double size) {
    final currentSize = _sheetController.size;
    final isMinimizing = size < currentSize;
    return _sheetController.animateTo(
      size,
      duration: isMinimizing ? Durations.short4 : Durations.long2,
      curve: Curves.easeInOutCubicEmphasized,
    );
  }
}
