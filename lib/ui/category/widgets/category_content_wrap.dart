import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/category/widgets/category_chip.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class CategoryContentWrap extends StatelessWidget {
  const CategoryContentWrap({
    required this.onCategorySelected,
    this.chipBackgroundColor,
    this.selectedCategory,
    this.onCategoryDeleted,
    super.key,
  });

  final void Function(ContentCategory) onCategorySelected;
  final Color? chipBackgroundColor;
  final ContentCategory? selectedCategory;
  final void Function()? onCategoryDeleted;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: UnmodifiableListView(
        ContentCategory.values.minusUnknown.map((category) {
          final isSelected = selectedCategory == category;
          return CategoryChip(
            category,
            backgroundColor: chipBackgroundColor,
            isSelected: isSelected,
            onDeleted: isSelected ? onCategoryDeleted : null,
            onPressed: () => onCategorySelected(category),
          );
        }),
      ),
    );
  }
}
