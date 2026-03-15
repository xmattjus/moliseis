import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/build_context_extensions.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class AppPageIndicator extends StatelessWidget {
  const AppPageIndicator({
    super.key,
    required this.pageController,
    required this.itemCount,
  }) : index = null;

  const AppPageIndicator.animated({
    super.key,
    required this.index,
    required this.itemCount,
  }) : pageController = null;

  final PageController? pageController;
  final int? index;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.colorScheme.secondaryContainer;
    final activeDotColor = context.colorScheme.onSecondaryContainer;
    final dotColor = activeDotColor.withValues(alpha: 0.45);

    final effect = WormEffect(
      dotHeight: 8.0,
      dotWidth: 8.0,
      activeDotColor: activeDotColor,
      dotColor: dotColor,
    );

    final pageIndicator = pageController != null
        ? SmoothPageIndicator(
            controller: pageController!,
            count: itemCount,
            effect: effect,
          )
        : AnimatedSmoothIndicator(
            activeIndex: index ?? 0,
            count: itemCount,
            effect: effect,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appShapes.circular.cornerFull,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
        child: pageIndicator,
      ),
    );
  }
}
