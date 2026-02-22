import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SearchAnchorSkeletonList extends StatelessWidget {
  const SearchAnchorSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    // The number of skeleton items to display in the list.
    const length = 10;

    final colorScheme = context.colorScheme;

    final item = Container(
      color: Colors.black,
      width: double.maxFinite,
      height: 88.0,
    );

    return Skeletonizer(
      effect: AppPulseEffect(
        from: colorScheme.surfaceContainerHigh,
        to: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TextSectionDivider('Risultati rapidi'),
          ...List.generate(length, (index) {
            if (index.isEven) {
              return item;
            } else {
              return const Divider();
            }
          }),
        ],
      ),
    );
  }
}
