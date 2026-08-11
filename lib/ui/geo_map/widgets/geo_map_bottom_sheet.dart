import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_surface.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_explore.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_post.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_search_results.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

class GeoMapBottomSheet extends StatefulWidget {
  const GeoMapBottomSheet({
    super.key,
    required this.content,
    required this.isResolvingRequestedSelection,
    required this.controller,
    required this.currentCenter,
    required this.onCloseButtonPressed,
    required this.onContentPressed,
    required this.onVerticalDragUpdate,
    this.searchQuery = '',
    required this.viewModel,
    required this.searchViewModel,
    required this.weatherViewModel,
  });

  /// Fully resolved content to display, or null when the sheet should show
  /// search results or nearby content.
  final ContentBase? content;

  /// True while the screen resolves a requested deep-link selection.
  ///
  /// A resolving selection takes precedence over previously displayed content
  /// so a stale post is never rendered for a newly requested identity.
  final bool isResolvingRequestedSelection;

  final DraggableScrollableController controller;

  /// The current map center.
  ///
  /// Used by the nearby-content view when [content] is null.
  final LatLng currentCenter;
  final VoidCallback onCloseButtonPressed;
  final void Function(ContentBase content) onContentPressed;
  final void Function(double size) onVerticalDragUpdate;
  final String searchQuery;
  final GeoMapViewModel viewModel;
  final SearchViewModel searchViewModel;
  final WeatherViewModel weatherViewModel;

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
  }

  @override
  void dispose() {
    _controller.removeListener(_onVerticalDragUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return AppBottomSheet(
      minChildSize: _minSize,
      snapSizes: _snapSizes,
      controller: _controller,
      builder: (context, scrollController) {
        final content = widget.content;
        final isResolving = widget.isResolvingRequestedSelection;
        final showPost = !isResolving && content != null;
        late final Widget child;

        if (isResolving) {
          child = SliverSkeletonizer(
            effect: AppPulseEffect(
              from: colorScheme.surfaceContainerHigh,
              to: colorScheme.surfaceContainerLow,
            ),
            child: SliverPadding(
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 16,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  Text(
                    'Esplora Placeholder: nome di un luogo',
                    style: AppTextStyles.title(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Placeholder: nome di un paese',
                    style: AppTextStyles.subtitle(context),
                  ),
                ],
              ),
            ),
          );
        } else if (content != null) {
          // The screen already resolved this selection; re-executing its
          // command would clear the successful result and reintroduce loading.
          child = GeoMapModalPost(
            key: ValueKey((content.runtimeType, content.remoteId)),
            content: content,
            onContentPressed: widget.onContentPressed,
            onCloseButtonPressed: widget.onCloseButtonPressed,
            viewModel: widget.viewModel,
            weatherViewModel: widget.weatherViewModel,
            scrollController: scrollController,
          );
        } else if (widget.searchQuery.isNotEmpty) {
          child = GeoMapModalSearchResults(
            widget.searchQuery,
            onResultPressed: widget.onContentPressed,
            onBackPressed: widget.onCloseButtonPressed,
            viewModel: widget.searchViewModel,
          );
        } else {
          child = GeoMapModalExplore(
            currentMapCenter: widget.currentCenter,
            onNearContentPressed: widget.onContentPressed,
            viewModel: widget.viewModel,
          );
        }

        if (showPost) {
          return AppBottomSheetSurface(child: child);
        }

        return AppBottomSheetSurface(
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: AppBottomSheetDragHandle()),
              child,

              SliverPadding(
                padding: EdgeInsets.only(bottom: context.bottomPadding),
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
