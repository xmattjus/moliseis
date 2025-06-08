import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';

class SuggestionCTAButton extends StatelessWidget {
  const SuggestionCTAButton({super.key, required this.onPressed});

  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).colorScheme.tertiaryFixed;
    final fgColor = Theme.of(context).colorScheme.onTertiaryFixed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112.0),
          child: Card(
            color: bgColor,
            elevation: 0.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26.0),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4.0,
                          children: [
                            Text(
                              'Suggerisci un luogo o evento',
                              style: CustomTextStyles.titleSmaller(
                                context,
                              )?.copyWith(color: fgColor),
                            ),
                            Text(
                              'Fai scoprire i migliori luoghi o eventi che il '
                              'Molise ha da offrire!',
                              style: TextStyle(color: fgColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(Icons.maps_ugc, color: fgColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
