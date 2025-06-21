import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/ui/core/themes/color.dart';
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
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: CustomColorSchemes.fromAttractionType(
          attractionType,
          Theme.of(context).brightness,
        ),
      ),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(attractionType.iconAlt),
        label: Text(attractionType.label),
      ),
    );
  }
}
