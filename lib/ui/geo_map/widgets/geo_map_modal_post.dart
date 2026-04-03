import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_close_button.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/utils/slideshow_visibility_notifier.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_action_buttons.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_description.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_header.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_nearby_content.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_slideshow.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/utils/extensions/build_context_extensions.dart';

const double _mediaSlideshowHeight = 450.0;

/// Shows a post inside the geo-map bottom sheet.
///
/// Reuses the shared post sections while adapting the layout to the map
/// context, including a modal close affordance and weather details.
class GeoMapModalPost extends StatefulWidget {
  const GeoMapModalPost({
    super.key,
    required this.content,
    required this.onCloseButtonPressed,
    required this.onContentPressed,
    required this.viewModel,
    required this.weatherViewModel,
    required this.scrollController,
  });

  final ContentBase content;

  /// Called when the close button has been pressed or otherwise activated.
  final VoidCallback onCloseButtonPressed;
  final void Function(ContentBase content) onContentPressed;
  final GeoMapViewModel viewModel;
  final WeatherViewModel weatherViewModel;
  final ScrollController scrollController;

  @override
  State<GeoMapModalPost> createState() => _GeoMapModalPostState();
}

class _GeoMapModalPostState extends State<GeoMapModalPost> {
  ScrollController get _scrollController => widget.scrollController;

  late final SlideshowVisibilityNotifier _slideshowVisibilityNotifier =
      SlideshowVisibilityNotifier(threshold: _mediaSlideshowHeight * 0.6);

  @override
  void dispose() {
    _slideshowVisibilityNotifier.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    _slideshowVisibilityNotifier.updateVisibilityFromNotification(notification);

    // Returning false allows the notification to continue
    // bubbling up to ancestor listeners.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          if (widget.content.media.isNotEmpty)
            PostSectionSlideshow(
              height: _mediaSlideshowHeight,
              media: widget.content.media,
              visibilityNotifier: _slideshowVisibilityNotifier.notifier,
              overlayBuilder: (context) => _buildTopControls(context),
            )
          else
            SliverToBoxAdapter(child: _buildTopControls(context)),
          PostSectionHeader(
            content: widget.content,
            weatherViewModel: widget.weatherViewModel,
          ),
          PostSectionActionButtons(
            content: widget.content,
            onCategoryPressed: () {
              // TODO(xmattjus): Implement category filtering when the category chip is pressed.
            },
          ),
          PostSectionDescription(content: widget.content),
          PostSectionNearbyContent(
            coordinates: widget.content.coordinates,
            onContentPressed: widget.onContentPressed,
            loadNearContentCommand: widget.viewModel.loadNearContent,
            nearContent: widget.viewModel.nearContent,
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: context.bottomPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    return SizedBox(
      height: 64.0,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: Center(
              child: AppBottomSheetDragHandle(
                color: context.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Positioned(
            top: 8.0,
            right: 16.0,
            child: AppBottomSheetCloseButton(
              onClose: widget.onCloseButtonPressed,
            ),
          ),
        ],
      ),
    );
  }
}
