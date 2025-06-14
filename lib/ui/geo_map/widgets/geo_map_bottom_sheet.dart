import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/attraction_and_place_names.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/button_list.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/link_text_button.dart';
import 'package:moliseis/ui/core/ui/near_attractions_list.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';

part '_geo_map_bottom_sheet_default.dart';
part '_geo_map_bottom_sheet_details.dart';
part '_geo_map_bottom_sheet_search.dart';

class GeoMapBottomSheet extends StatefulWidget {
  const GeoMapBottomSheet({
    super.key,
    required this.attractionId,
    this.searchQuery = '',
    required this.controller,
    required this.currentCenter,
    required this.onAttractionPressed,
    required this.onCloseButtonPressed,
    required this.onVerticalDragUpdate,
  });

  /// The user selected attraction's local database id.
  final int attractionId;

  final String searchQuery;

  /// The controller for the bottom sheet.
  final DraggableScrollableController controller;

  /// The current map center.
  ///
  /// When both the [_attractionId] and [currentCenter] are defined, the first
  /// will take priority, e.g. the details of that [Attraction] will be shown in
  /// the bottom sheet.
  final LatLng currentCenter;

  final VoidCallback onCloseButtonPressed;

  final void Function(int id) onAttractionPressed;

  final void Function(double size) onVerticalDragUpdate;

  @override
  State<GeoMapBottomSheet> createState() => _GeoMapBottomSheetState();
}

class _GeoMapBottomSheetState extends State<GeoMapBottomSheet>
    with TickerProviderStateMixin {
  DraggableScrollableController get _controller => widget.controller;

  late final AttractionViewModel _uiAttractionController;

  Future<Attraction>? _future;

  double _minSize = 0;

  final List<double> _snapSizes = [0.2, 0.35, 0.5];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onVerticalDragUpdate);

    _uiAttractionController = context.read();

    if (widget.attractionId > 0) {
      _updateFuture('${widget.attractionId}');
    }
  }

  @override
  void didUpdateWidget(covariant GeoMapBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (context.isLandscape) {
      _updateMinSize(0.35);

      /// Removes the snap sizes that would make dragging the bottom sheet
      /// behind the navigation bar without closing it possible in landscape.
      _snapSizes.remove(0.2);
    } else {
      _updateMinSize(0.2);

      if (!_snapSizes.contains(0.2)) {
        _snapSizes.insert(0, 0.2);
      }
    }

    if (widget.attractionId != oldWidget.attractionId) {
      if (widget.attractionId > 0) {
        _updateFuture('${widget.attractionId}');
      } else {
        _future = null;
      }
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

        if (widget.searchQuery.isNotEmpty) {
          child = _GeoMapBottomSheetSearch(
            widget.searchQuery,
            onResultPressed: widget.onAttractionPressed,
            onBackPressed: widget.onCloseButtonPressed,
          );
        } else if (widget.attractionId > 0) {
          child = _GoeMapBottomSheetDetails(
            attractionId: widget.attractionId,
            onNearAttractionTap: widget.onAttractionPressed,
            onCloseButtonTap: widget.onCloseButtonPressed,
            future: _future,
          );
        } else {
          child = _GeoMapBottomSheetDefault(
            currentMapCenter: widget.currentCenter,
            onNearAttractionTap: widget.onAttractionPressed,
          );
        }

        return Material(
          elevation: 1.0,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: _Draggable()),
              child,

              // Adds some padding to prevent the bottom navigation bar
              // from overlapping the bottom sheet content.
              const SliverPadding(
                padding: EdgeInsetsDirectional.only(
                  bottom: kNavigationBarHeight + 32.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Notifies its listeners on [_controller] size changes.
  void _onVerticalDragUpdate() => widget.onVerticalDragUpdate(_controller.size);

  Future<void> _updateFuture(String id) =>
      _future = _uiAttractionController.getAttractionById(id);

  /// Changes the bottom sheet minimum size to disallow closing it completely
  /// when an attraction is open.
  void _updateMinSize(double newSize) {
    if (widget.attractionId != 0) {
      _minSize = newSize;
    } else {
      _minSize = 0;
    }
  }
}

class _Draggable extends StatelessWidget {
  const _Draggable();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 9.0),
        width: 32.0,
        height: 4.0,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
