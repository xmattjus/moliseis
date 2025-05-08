import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/cards/attraction_card_title_subtitle.dart';
import 'package:moliseis/ui/core/ui/cards/base_attraction_card.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/skeletons/card_skeleton_carousel_item.dart';

class ExploreScreenCarouselView extends StatelessWidget {
  const ExploreScreenCarouselView({
    super.key,
    required this.attractionsIdsFuture,
  });

  final Future<List<int>> attractionsIdsFuture;

  @override
  Widget build(BuildContext context) {
    const sectionTextTopPadding = 0.0; // 16.0;
    const sectionTextBottomPadding = 8.0;

    final sectionTextStyle = CustomTextStyles.section(context);

    /// The height the widget will have.
    final height =
        MediaQuery.sizeOf(context).height * 0.45 -
        (sectionTextTopPadding +
            sectionTextBottomPadding +
            (sectionTextStyle?.height ?? 16.0));

    /// The maximum extent a CarouselView child will have in the main axis.
    /// This is necessary to correctly size the image of each child.
    ///
    /// See the CarouselView's 'flexWeights' property for more info.
    final maxWidthExtent = (6 / (1 + 6 + 1)) * MediaQuery.sizeOf(context).width;

    return SliverList.list(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            16.0,
            sectionTextTopPadding,
            16.0,
            sectionTextBottomPadding,
          ),
          child: CustomRichText(
            const Text('Suggeriti'),
            labelTextStyle: CustomTextStyles.section(context),
          ),
        ),
        FutureBuilt<List<int>>(
          attractionsIdsFuture,
          onLoading: () {
            return SizedBox(
              height: height,
              child: const Center(
                child: CustomCircularProgressIndicator.withDelay(),
              ),
            );
          },
          onSuccess: (data) {
            return SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 8.0,
                  end: 16.0,
                ),
                child: CarouselView.weighted(
                  padding: const EdgeInsets.only(left: 8.0),
                  elevation: 0,
                  itemSnapping: true,
                  onTap: (value) {
                    GoRouter.of(context).goNamed(
                      RouteNames.exploreStory,
                      pathParameters: {'id': data[value].toString()},
                    );
                  },
                  flexWeights: const [6, 3, 2],
                  children: UnmodifiableListView<_CarouselViewItem>(
                    data.map<_CarouselViewItem>(
                      (int id) => _CarouselViewItem(
                        attractionId: id,
                        width: maxWidthExtent,
                        height: height,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          onError: (error) {
            return SizedBox(
              height: height,
              child: const EmptyView.error(
                text: Text('Si è verificato un errore durante il caricamento.'),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CarouselViewItem extends StatelessWidget {
  const _CarouselViewItem({
    required this.attractionId,
    required this.width,
    required this.height,
  });

  final int attractionId;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return BaseAttractionCard(
      attractionId,
      onLoading: () => const CardSkeletonCarouselItem(),
      builder: (attraction, image, place) {
        return Stack(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withAlpha(40)),
              position: DecorationPosition.foreground,
              child: CustomImage(
                image,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 16.0,
              bottom: 16.0,
              right: 16.0,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final show = constraints.maxWidth > 90;
                  return AnimatedOpacity(
                    opacity: show ? 1 : 0,
                    duration: show ? Durations.medium4 : Duration.zero,
                    curve: Easing.standardDecelerate,
                    child: AttractionCardTitleSubtitle(
                      attraction.name,
                      place.name,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
