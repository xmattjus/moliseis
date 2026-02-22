import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SuggestedCarouselView extends StatelessWidget {
  const SuggestedCarouselView({super.key, required this.exploreViewModel});

  final ExploreViewModel exploreViewModel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    const sectionTextBottomPadding = 8.0;

    final flexWeights = switch (context.windowSizeClass) {
      WindowSizeClass.compact => [6, 3, 2],
      WindowSizeClass.medium => [7, 4, 3, 2],
      _ => [8, 5, 4, 3, 2],
    };

    final height =
        (MediaQuery.sizeOf(context).height * 0.45) -
        sectionTextBottomPadding +
        (AppTextStyles.section(context)?.height ?? 16.0);

    // The maximum extent a CarouselView child will have in the main axis.
    // Necessary to correctly size the image of each child and prevent rebuilds.
    //
    // See the CarouselView's 'flexWeights' property for more info.
    final maxWidthExtent = (6 / (1 + 6 + 1)) * MediaQuery.sizeOf(context).width;

    return SliverList.list(
      children: [
        const TextSectionDivider(
          'Suggeriti',
          padding: EdgeInsetsDirectional.fromSTEB(
            16.0,
            0,
            16.0,
            sectionTextBottomPadding,
          ),
        ),
        SizedBox(
          height: height,
          child: ListenableBuilder(
            listenable: exploreViewModel.loadSuggested,
            builder: (context, child) {
              final length = exploreViewModel.suggestedIds.length;

              if (exploreViewModel.loadSuggested.error) {
                return SizedBox(
                  height: height,
                  child: const EmptyView.error(
                    text: Text(
                      'Si è verificato un errore durante il caricamento.',
                    ),
                  ),
                );
              }

              // Generates a list of placeholders while loading the suggested
              // places from the repository.
              final List<Widget> children =
                  exploreViewModel.loadSuggested.running
                  ? List.generate(length, (index) {
                      return Container(
                        color: Colors.black,
                        width: double.maxFinite,
                        height: height,
                      );
                    })
                  : UnmodifiableListView<Widget>(
                      exploreViewModel.suggested.map<Widget>(
                        (PlaceContent content) => _CarouselViewItem(
                          content: content,
                          width: maxWidthExtent,
                          height: height,
                        ),
                      ),
                    );

              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 8.0,
                  end: 16.0,
                ),
                child: Skeletonizer(
                  enabled: exploreViewModel.loadSuggested.running,
                  effect: AppPulseEffect(
                    from: colorScheme.surfaceContainerHigh,
                    to: colorScheme.surfaceContainerLow,
                  ),
                  child: CarouselView.weighted(
                    padding: const EdgeInsets.only(left: 8.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: context.appShapes.circular.cornerExtraLarge,
                    ),
                    itemSnapping: true,
                    enableSplash: false,
                    flexWeights: flexWeights,
                    children: children,
                  ),
                ),
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
    required this.content,
    required this.width,
    required this.height,
  });

  final PlaceContent content;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (content.media.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(color: Colors.black.withAlpha(40)),
            position: DecorationPosition.foreground,
            child: CustomImage.network(
              content.media.first.url,
              width: width,
              height: height,
              imageWidth: content.media.first.width,
              imageHeight: content.media.first.height,
              fit: BoxFit.cover,
            ),
          ),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: CustomInkWell(
              onPressed: () => GoRouter.of(context).goNamed(
                RouteNames.homePost,
                pathParameters: {'id': content.remoteId.toString()},
                queryParameters: {
                  'isEvent': (content is EventContent ? 'true' : 'false'),
                },
              ),
            ),
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
                        color: Colors.white,
                        content: content,
                        borderRadius: context.appShapes.circular.cornerLarge,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ContentNameAndCity(
                        name: content.name,
                        cityName: content.city.target?.name,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
