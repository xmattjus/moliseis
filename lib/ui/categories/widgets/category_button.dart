import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/ui/core/themes/color.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/utils/extensions.dart';

class CategoryButton extends StatelessWidget {
  const CategoryButton({
    super.key,
    required this.onPressed,
    required this.attractionType,
  });

  final void Function() onPressed;
  final AttractionType attractionType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.colorScheme.primary;
    final b = theme.brightness;
    final Color? bgColor;
    final Color? fgColor;

    switch (attractionType) {
      case AttractionType.unknown:
        bgColor = null;
        fgColor = null;
      case AttractionType.nature:
        bgColor = CustomColorSchemes.nature(p, b).surfaceContainerLow;
        fgColor = CustomColorSchemes.nature(p, b).primary;
      case AttractionType.history:
        bgColor = CustomColorSchemes.history(p, b).surfaceContainerLow;
        fgColor = CustomColorSchemes.history(p, b).primary;
      case AttractionType.folklore:
        bgColor = CustomColorSchemes.folklore(p, b).surfaceContainerLow;
        fgColor = CustomColorSchemes.folklore(p, b).primary;
      case AttractionType.food:
        bgColor = CustomColorSchemes.food(p, b).surfaceContainerLow;
        fgColor = CustomColorSchemes.food(p, b).primary;
      case AttractionType.allure:
        bgColor = CustomColorSchemes.allure(p, b).surfaceContainerLow;
        fgColor = CustomColorSchemes.allure(p, b).primary;
      case AttractionType.experience:
        bgColor = CustomColorSchemes.experience(p, b).surfaceContainerLow;
        fgColor = CustomColorSchemes.experience(p, b).primary;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Shapes.medium),
        ),
      ),
      icon: Icon(attractionType.iconAlt),
      label: Text(attractionType.label),
    );
  }
}
