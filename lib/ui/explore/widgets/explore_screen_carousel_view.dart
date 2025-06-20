import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/themes/shape.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/attraction_and_place_names.dart';
import 'package:moliseis/ui/core/ui/cards/base_attraction_card.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/skeletons/card_skeleton_carousel_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';

class ExploreScreenCarouselView extends StatelessWidget {
  const ExploreScreenCarouselView({
    super.key,
    required this.attractionsIdsFuture,
  });

  final Future<List<int>> attractionsIdsFuture;

  @override
  Widget build(BuildContext context) {
    const sectionTextBottomPadding = 8.0;

    final sectionTextStyle = CustomTextStyles.section(context);

    final height =
        (MediaQuery.sizeOf(context).height * 0.45) -
        sectionTextBottomPadding +
        (sectionTextStyle?.height ?? 16.0);

    // The maximum extent a CarouselView child will have in the main axis.
    // Necessary to correctly size the image of each child and prevent rebuilds.
    //
    // See the CarouselView's 'flexWeights' property for more info.
    final maxWidthExtent = (6 / (1 + 6 + 1)) * MediaQuery.sizeOf(context).width;

    return SliverList.list(
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16.0,
            0,
            16.0,
            sectionTextBottomPadding,
          ),
          child: TextSectionDivider('Suggeriti'),
        ),
        SizedBox(
          height: height,
          child: FutureBuilt<List<int>>(
            attractionsIdsFuture,
            onLoading: () {
              return const EmptyView.loading(
                text: Text('Caricamento in corso...'),
              );
            },
            onSuccess: (data) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 8.0,
                  end: 16.0,
                ),
                child: CarouselView.weighted(
                  padding: const EdgeInsets.only(left: 8.0),
                  elevation: 0.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Shape.extraLarge),
                  ),
                  itemSnapping: true,
                  enableSplash: false,
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
              );
            },
            onError: (error) {
              return const EmptyView.error(
                text: Text('Si è verificato un errore durante il caricamento.'),
              );
            },
          ),
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
              child: CardBase(
                child: CustomImage.network(
                  image.url,
                  width: width,
                  height: height,
                  imageWidth: image.width.toDouble(),
                  imageHeight: image.height.toDouble(),
                  fit: BoxFit.cover,
                ),
                onPressed: () {
                  GoRouter.of(context).goNamed(
                    RouteNames.homeStory,
                    pathParameters: {'id': attraction.id.toString()},
                  );
                },
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final show = constraints.maxWidth > 100.0;
                return AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: show ? Durations.medium4 : Duration.zero,
                  curve: Easing.standardDecelerate,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsetsDirectional.all(8.0),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: FavouriteButton(
                            color: Colors.white70,
                            id: attraction.id,
                            radius: Shape.full,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: AttractionAndPlaceNames(
                          name: attraction.name,
                          placeName: place.name,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
