import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:skeletonizer/skeletonizer.dart';

class InformationCard extends StatelessWidget {
  const InformationCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.useBoldSubtitle = true,
    this.enableSkeletonizer = true,
    this.onPressed,
  });

  /// Tipically an icon or an image that represents the content.
  final Widget leading;

  final Widget title;
  final Widget? subtitle;

  final bool useBoldSubtitle;

  final bool enableSkeletonizer;

  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);

    final subtitle = useBoldSubtitle
        ? DefaultTextStyle.merge(
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            child: this.subtitle ?? const EmptyBox(),
          )
        : this.subtitle ?? const EmptyBox();

    final rightPart = Expanded(
      child: enableSkeletonizer
          ? Skeletonizer(
              effect: CustomPulseEffect(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[title, subtitle],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2.0,
              children: <Widget>[title, subtitle],
            ),
    );

    return CardBase.filled(
      color: Theme.of(context).colorScheme.secondaryContainer,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16.0,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 24.0,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                child: leading,
              ),
            ),
            DefaultTextStyle.merge(
              style: textTheme.bodyMedium,
              child: rightPart,
            ),
          ],
        ),
      ),
    );
  }
}
