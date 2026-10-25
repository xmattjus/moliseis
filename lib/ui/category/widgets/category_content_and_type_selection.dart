import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/app_show_modal_bottom_sheet.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class CategoryContentAndTypeSelection extends StatefulWidget {
  const CategoryContentAndTypeSelection({
    required this.selectedCategories,
    required this.selectedTypes,
    required this.onCategorySelectionChanged,
    required this.onTypeSelectionChanged,
    this.chipBackgroundColor,
    super.key,
  });

  final Set<ContentCategory> selectedCategories;
  final Set<ContentType> selectedTypes;
  final void Function(Set<ContentCategory> categories)
  onCategorySelectionChanged;
  final void Function(Set<ContentType> types) onTypeSelectionChanged;
  final Color? chipBackgroundColor;

  @override
  State<CategoryContentAndTypeSelection> createState() =>
      _CategoryContentAndTypeSelectionState();
}

class _CategoryContentAndTypeSelectionState
    extends State<CategoryContentAndTypeSelection> {
  late Set<ContentCategory> _selectedCategories;
  late Set<ContentType> _selectedTypes;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.of(widget.selectedCategories);
    _selectedTypes = Set.of(widget.selectedTypes);
  }

  @override
  void didUpdateWidget(covariant CategoryContentAndTypeSelection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!setEquals(oldWidget.selectedCategories, widget.selectedCategories)) {
      _selectedCategories = Set.of(widget.selectedCategories);
    }

    if (!setEquals(oldWidget.selectedTypes, widget.selectedTypes)) {
      _selectedTypes = Set.of(widget.selectedTypes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          InputChip(
            label: Text(
              _selectedTypes.isEmpty
                  ? 'Nessun tipo'
                  : _selectedTypes.containsAll({
                      ContentType.event,
                      ContentType.place,
                    })
                  ? 'Tipo'
                  : _selectedTypes.contains(ContentType.event)
                  ? 'Eventi'
                  : 'Luoghi',
            ),
            deleteIcon: const Icon(Symbols.arrow_drop_down),
            onDeleted: _onTypeChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per tipo',
            onPressed: _onTypeChipPressed,
          ),
          InputChip(
            label: Text(
              _selectedCategories.isEmpty
                  ? 'Nessuna categoria'
                  : _selectedCategories.length ==
                        ContentCategory.values.minusUnknown.length
                  ? 'Categoria'
                  : _selectedCategories.first.label +
                        (_selectedCategories.length > 1
                            ? ' + ${_selectedCategories.length - 1}'
                            : ''),
            ),
            deleteIcon: const Icon(Symbols.arrow_drop_down),
            onDeleted: _onCategoryChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per categoria',
            onPressed: _onCategoryChipPressed,
          ),
        ],
      ),
    );
  }

  Future<void> _onTypeChipPressed() async {
    final draft = _selectedTypes;
    final onChanged = widget.onTypeSelectionChanged;
    await _showAdaptiveSelectionWidget<void>(
      title: 'Seleziona per tipo',
      children: UnmodifiableListView(
        ContentType.values.map<Widget>(
          (type) => _buildSelectionRow(
            label: type.label,
            itemKey: ValueKey<ContentType>(type),
            isSelected: draft.contains(type),
            onChanged: (value) => _toggleItem(draft, type, value),
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (!identical(draft, _selectedTypes)) return;

    setState(() {
      // Empty is valid while editing; normalize only this current session.
      if (draft.isEmpty) draft.addAll(ContentType.values);
    });
    onChanged(Set.of(draft));
  }

  Future<void> _onCategoryChipPressed() async {
    final draft = _selectedCategories;
    final onChanged = widget.onCategorySelectionChanged;
    await _showAdaptiveSelectionWidget<void>(
      title: 'Seleziona per categoria',
      children: UnmodifiableListView(
        ContentCategory.values.minusUnknown.map<Widget>(
          (category) => _buildSelectionRow(
            label: category.label,
            itemKey: ValueKey<ContentCategory>(category),
            isSelected: draft.contains(category),
            onChanged: (value) => _toggleItem(draft, category, value),
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (!identical(draft, _selectedCategories)) return;

    setState(() {
      if (draft.isEmpty) draft.addAll(ContentCategory.values.minusUnknown);
    });
    onChanged(Set.of(draft));
  }

  Future<T?> _showAdaptiveSelectionWidget<T>({
    required String title,
    required List<Widget> children,
  }) async {
    if (context.windowSizeClass.isAtMost(WindowSizeClass.medium)) {
      return await _showGenericSelectionBottomSheet<T>(
        title: title,
        children: children,
      );
    } else {
      return await showDialog<T?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: context.textTheme.bodyLarge),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Salva'),
            ),
          ],
        ),
      );
    }
  }

  Future<T?> _showGenericSelectionBottomSheet<T>({
    required String title,
    required List<Widget> children,
  }) => appShowModalBottomSheet<T?>(
    context: context,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Align(child: AppBottomSheetDragHandle()),
            const SizedBox(height: 16),
            AppBottomSheetTitle(
              title: title,
              tooltipMessage: 'Salva',
              icon: Symbols.check,
              onClose: () => context.pop(),
            ),
            const SizedBox(height: 16),
            ...children,
            SizedBox(height: context.bottomPadding),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );

  Widget _buildSelectionRow({
    required String label,
    required Key itemKey,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
  }) {
    var selected = isSelected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 16,
      children: <Widget>[
        Text(label),
        StatefulBuilder(
          builder: (_, setState) => Checkbox(
            key: itemKey,
            value: selected,
            onChanged: (value) {
              setState(() {
                selected = value ?? false;
                onChanged(value);
              });
            },
          ),
        ),
      ],
    );
  }

  void _toggleItem<T>(Set<T> set, T item, bool? value) {
    value ?? false ? set.add(item) : set.remove(item);
  }
}
