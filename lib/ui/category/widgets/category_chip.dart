import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

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
  Widget build(BuildContext context) => Theme(
    data: context.theme.copyWith(
      colorScheme: context.appColorSchemes.byCategory(category),
    ),
    child: InputChip(
      avatar: Icon(isSelected ? Symbols.check : category.icon),
      label: Text(category.label),
      selected: isSelected,
      deleteIcon: isSelected ? const Icon(Symbols.close) : null,
      onDeleted: onDeleted,
      backgroundColor: backgroundColor,
      onPressed: onPressed,
      showCheckmark: false,
    ),
  );
}
