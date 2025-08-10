import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/domain/models/place/place_content.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_adaptive_title.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/content/event_content_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/place_content_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet_details.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_bottom_sheet_search.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

class GeoMapBottomSheet extends StatefulWidget {
  const GeoMapBottomSheet({
    super.key,
    // required this.contentId,
    required this.content,
    required this.controller,
    required this.currentCenter,
    required this.onCloseButtonPressed,
    required this.onContentPressed,
    required this.onVerticalDragUpdate,
    this.searchQuery = '',
    required this.viewModel,
    required this.searchViewModel,
  });

  // final int contentId;
  final ContentBase? content;

  final DraggableScrollableController controller;

  /// The current map center.
  ///
  /// When both the [contentId] and [currentCenter] are defined, the first
  /// will take priority, e.g. the details of that [Place] will be shown in
  /// the bottom sheet.
  final LatLng currentCenter;

  final VoidCallback onCloseButtonPressed;

  final void Function(ContentBase content) onContentPressed;

  final void Function(double size) onVerticalDragUpdate;

  final String searchQuery;

  final GeoMapViewModel viewModel;

  final SearchViewModel searchViewModel;

  @override
  State<GeoMapBottomSheet> createState() => _GeoMapBottomSheetState();
}

class _GeoMapBottomSheetState extends State<GeoMapBottomSheet>
    with TickerProviderStateMixin {
  DraggableScrollableController get _controller => widget.controller;

  double _minSize = 0;

  final List<double> _snapSizes = [0.2, 0.35, 0.5];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onVerticalDragUpdate);

    if (widget.content != null) {
      _showContent();
    }
  }

  @override
  void didUpdateWidget(covariant GeoMapBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (context.isLandscape) {
      _updateMinSize(0.35);

      /// Removes the snap sizes that would make possible to drag the bottom
      /// sheet behind the navigation bar without completely closing it in
      /// landscape.
      _snapSizes.remove(0.2);
    } else {
      _updateMinSize(0.2);

      if (!_snapSizes.contains(0.2)) {
        _snapSizes.insert(0, 0.2);
      }
    }

    if (widget.content != null &&
        widget.content!.remoteId != oldWidget.content?.remoteId) {
      _showContent();
    }
  }

  void _showContent() {
    if (widget.content! is EventContent) {
      widget.viewModel.showEvent.execute(widget.content!.remoteId);
    } else if (widget.content! is PlaceContent) {
      widget.viewModel.showPlace.execute(widget.content!.remoteId);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVerticalDragUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: _minSize,
      snap: true,
      snapSizes: _snapSizes,
      snapAnimationDuration: Durations.short4,
      controller: _controller,
      builder: (context, scrollController) {
        Widget? child;

        final id = widget.content?.remoteId ?? 0;

        if (id > 0) {
          child = ListenableBuilder(
            listenable: Listenable.merge([
              widget.viewModel.showEvent,
              widget.viewModel.showPlace,
            ]),
            builder: (_, _) {
              if (widget.content! is EventContent &&
                      widget.viewModel.showEvent.completed ||
                  widget.content! is PlaceContent &&
                      widget.viewModel.showPlace.completed) {
                return GeoMapBottomSheetDetails(
                  widget.viewModel.selectedContent!,
                  onNearContentPressed: widget.onContentPressed,
                  onCloseButtonPressed: widget.onCloseButtonPressed,
                  viewModel: widget.viewModel,
                );
              }

              return SliverSkeletonizer(
                effect: CustomPulseEffect(context: context),
                child: SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18.0,
                    horizontal: 16.0,
                  ),
                  sliver: SliverList.list(
                    children: <Widget>[
                      Text(
                        'Esplora Placeholder: nome di un luogo',
                        style: CustomTextStyles.title(context),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Placeholder: nome di un paese',
                        style: CustomTextStyles.subtitle(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else if (widget.searchQuery.isNotEmpty) {
          child = GeoMapBottomSheetSearch(
            widget.searchQuery,
            onResultPressed: widget.onContentPressed,
            onBackPressed: widget.onCloseButtonPressed,
            viewModel: widget.searchViewModel,
          );
        } else {
          child = GeoMapBottomSheetDefault(
            currentMapCenter: widget.currentCenter,
            onNearContentPressed: widget.onContentPressed,
            viewModel: widget.viewModel,
          );
        }

        return Material(
          elevation: 1.0,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Shapes.extraLarge),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: BottomSheetDragHandle()),
              child,

              // Adds some padding to prevent the bottom navigation bar
              // from overlapping the bottom sheet content.
              const SliverPadding(
                padding: EdgeInsets.only(bottom: kNavigationBarHeight + 32.0),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Notifies its listeners on [_controller] size changes.
  void _onVerticalDragUpdate() => widget.onVerticalDragUpdate(_controller.size);

  /// Changes the bottom sheet minimum size to disallow closing it completely
  /// when content is visible.
  void _updateMinSize(double newSize) {
    if (widget.content != null) {
      _minSize = newSize;
    } else {
      _minSize = 0;
    }
  }
}

class GeoMapBottomSheetDefault extends StatelessWidget {
  const GeoMapBottomSheetDefault({
    required this.currentMapCenter,
    required this.onNearContentPressed,
    required this.viewModel,
  });

  /// The current map center.
  final LatLng currentMapCenter;

  /// Returns the [Place] Id that has been tapped on.
  final void Function(ContentBase content) onNearContentPressed;

  final GeoMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: <Widget>[
        const BottomSheetAdaptiveTitle('Esplora i dintorni'),
        NearbyContentHorizontalList(
          coordinates: [currentMapCenter.latitude, currentMapCenter.longitude],
          onPressed: onNearContentPressed,
          viewModel: viewModel,
        ),
      ],
    );
  }
}

class NearbyContentHorizontalList extends StatefulWidget {
  const NearbyContentHorizontalList({
    // super.key,
    required this.coordinates,
    required this.onPressed,
    required this.viewModel,
  });

  final List<double> coordinates;
  final void Function(ContentBase content) onPressed;
  final GeoMapViewModel viewModel;

  @override
  State<NearbyContentHorizontalList> createState() =>
      _NearbyContentHorizontalListState();
}

class _NearbyContentHorizontalListState
    extends State<NearbyContentHorizontalList> {
  @override
  void initState() {
    super.initState();

    widget.viewModel.loadNearContent.execute(widget.coordinates);
  }

  @override
  void didUpdateWidget(covariant NearbyContentHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinates.first != widget.coordinates.first ||
        oldWidget.coordinates.last != widget.coordinates.last) {
      widget.viewModel.loadNearContent.execute(widget.coordinates);
    }
  }

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 4.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 8.0),
          child: TextSectionDivider('Nelle vicinanze'),
        ),
        SizedBox(
          height: kGridViewCardHeight,
          child: ListenableBuilder(
            listenable: widget.viewModel.loadNearContent,
            builder: (context, child) {
              if (widget.viewModel.loadNearContent.completed) {
                if (widget.viewModel.nearContent.isEmpty) {
                  return const EmptyView(
                    text: Text('Nessun luogo trovato nelle vicinanze.'),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, index) {
                    final content = widget.viewModel.nearContent[index];

                    if (content is EventContent) {
                      return EventContentCardGridItem(
                        content,
                        width: kGridViewCardWidth,
                        onPressed: () => widget.onPressed(content),
                        actions: <Widget>[
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: 8.0,
                              end: 8.0,
                            ),
                            child: FavouriteButton(
                              color: Colors.white70,
                              content: content,
                              radius: Shapes.small,
                            ),
                          ),
                        ],
                      );
                    }

                    return PlaceContentCardGridItem(
                      content,
                      width: kGridViewCardWidth,
                      onPressed: () => widget.onPressed(content),
                      actions: <Widget>[
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: 8.0,
                            end: 8.0,
                          ),
                          child: FavouriteButton(
                            color: Colors.white70,
                            content: content,
                            radius: Shapes.small,
                          ),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: widget.viewModel.nearContent.length,
                );
              }

              if (widget.viewModel.loadNearContent.error) {
                return const EmptyView.error(
                  text: Text(
                    'Si è verificato un errore durante il caricamento.',
                  ),
                );
              }

              return Skeletonizer(
                effect: CustomPulseEffect(context: context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, _) => const SkeletonContentGridItem(
                    width: kGridViewCardWidth,
                    height: kGridViewCardHeight,
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: 5,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
