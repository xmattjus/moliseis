import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';

class SuggestionCTAButton extends StatelessWidget {
  const SuggestionCTAButton({super.key, required this.onPressed});

  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).colorScheme.secondaryContainer;
    final fgColor = Theme.of(context).colorScheme.onSecondaryContainer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CardBase(
          color: bgColor,
          elevation: 0,
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4.0,
                      children: <Widget>[
                        Text(
                          'Suggerisci un luogo o un evento',
                          style: AppTextStyles.titleSmaller(
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
                Icon(Symbols.maps_ugc, color: fgColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
