import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/ui/core/themes/color.dart';
import 'package:moliseis/utils/extensions.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.element,
    required this.isSelected,
    this.onDeleted,
    required this.onPressed,
  });

  final AttractionType element;
  final bool isSelected;
  final void Function()? onDeleted;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: CustomColorSchemes.fromAttractionType(
          element,
          theme.brightness,
        ),
      ),
      child: InputChip(
        avatar: Icon(isSelected ? element.iconAlt : element.icon),
        label: Text(element.label),
        selected: isSelected,
        deleteIcon: isSelected ? const Icon(Icons.close) : null,
        onDeleted: onDeleted,
        onPressed: onPressed,
        showCheckmark: false,
      ),
    );
  }
}
