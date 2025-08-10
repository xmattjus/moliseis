import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/ui/core/themes/color_schemes.dart';
import 'package:moliseis/utils/extensions.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip(
    this.category, {
    super.key,
    this.backgroundColor,
    required this.isSelected,
    this.onDeleted,
    required this.onPressed,
  });

  final Color? backgroundColor;
  final ContentCategory category;
  final bool isSelected;
  final void Function()? onDeleted;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: CustomColorSchemes.fromContentCategory(
          category,
          theme.brightness,
        ),
      ),
      child: InputChip(
        avatar: Icon(isSelected ? Icons.check : category.icon),
        label: Text(category.label),
        selected: isSelected,
        deleteIcon: isSelected ? const Icon(Icons.close) : null,
        onDeleted: onDeleted,
        backgroundColor: backgroundColor,
        onPressed: onPressed,
        showCheckmark: false,
      ),
    );
  }
}
