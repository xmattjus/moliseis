import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_effects_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_sizes_theme_extension.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/themes/theme_data.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_title.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CategorySelectionList extends StatefulWidget {
  final Color? chipBackgroundColor;
  final void Function(Set<ContentCategory> selectedCategories)
  onCategoriesSelectionChanged;
  final void Function(Set<ContentType> selectedTypes) onTypesSelectionChanged;
  final Set<ContentCategory> selectedCategories;

  const CategorySelectionList({
    super.key,
    this.chipBackgroundColor,
    required this.onCategoriesSelectionChanged,
    required this.onTypesSelectionChanged,
    this.selectedCategories = const {},
  });

  @override
  State<CategorySelectionList> createState() => _CategorySelectionListState();
}

class _CategorySelectionListState extends State<CategorySelectionList> {
  var _selectedCategories = const <ContentCategory>{};
  final _selectedTypes = {ContentType.place, ContentType.event};

  @override
  void initState() {
    super.initState();

    if (widget.selectedCategories.isNotEmpty) {
      _selectedCategories = widget.selectedCategories;
    } else {
      _selectedCategories = ContentCategory.values.minusUnknown.toSet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64.0,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          RawChip(
            label: Text(
              _selectedTypes.containsAll({ContentType.event, ContentType.place})
                  ? 'Tipo'
                  : _selectedTypes.contains(ContentType.event)
                  ? 'Eventi'
                  : 'Luoghi',
            ),
            deleteIcon: const Icon(Icons.arrow_drop_down),
            onDeleted: _onTypeChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per tipo',
            onPressed: _onTypeChipPressed,
          ),
          const SizedBox(width: 8.0),
          InputChip(
            label: Text(
              _selectedCategories.length ==
                      ContentCategory.values.minusUnknown.length
                  ? 'Categoria'
                  : _selectedCategories.first.label +
                        (_selectedCategories.length > 1
                            ? ' + ${_selectedCategories.length - 1}'
                            : ''),
            ),
            deleteIcon: const Icon(Icons.arrow_drop_down),
            onDeleted: _onCategoryChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per categoria',
            onPressed: _onCategoryChipPressed,
          ),
        ],
      ),
    );
  }

  Future<void> _onTypeChipPressed() async {
    await _showGenericSelectionBottomSheet(
      title: 'Seleziona per tipo',
      children: UnmodifiableListView(
        ContentType.values.map<Widget>((type) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 16.0, end: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 16.0,
              children: <Widget>[
                Text(
                  type.label,
                  style: context.defaultTextStyle.style.copyWith(
                    color: Colors.white,
                  ),
                ),
                StatefulBuilder(
                  builder: (_, setState) {
                    return _SelectionWidget(
                      key: ValueKey<ContentType>(type),
                      isSelected: _selectedTypes.contains(type),
                      onChanged: (value) {
                        _changeSelectedTypes(value, type, setState);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );

    if (mounted) {
      setState(() {
        // If the user has selected no types, resets to the default
        // selection of all types.
        if (_selectedTypes.isEmpty) {
          _selectedTypes.addAll([ContentType.place, ContentType.event]);
        }
      });

      widget.onTypesSelectionChanged.call(_selectedTypes);
    }
  }

  Future<void> _onCategoryChipPressed() async {
    await _showGenericSelectionBottomSheet(
      title: 'Seleziona per categoria',
      children: UnmodifiableListView(
        ContentCategory.values.minusUnknown.map<Widget>((category) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 16.0, end: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 16.0,
              children: <Widget>[
                Text(
                  category.label,
                  style: context.defaultTextStyle.style.copyWith(
                    color: Colors.white,
                  ),
                ),
                StatefulBuilder(
                  builder: (_, setState) {
                    return _SelectionWidget(
                      key: ValueKey<ContentCategory>(category),
                      isSelected: _selectedCategories.contains(category),
                      onChanged: (value) {
                        _changeSelectedCategories(value, category, setState);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );

    if (mounted) {
      setState(() {
        // If the user has selected no categories, resets to the
        // default selection of all categories.
        if (_selectedCategories.isEmpty) {
          _selectedCategories.addAll(ContentCategory.values.minusUnknown);
        }
      });

      widget.onCategoriesSelectionChanged.call(_selectedCategories);
    }
  }

  Future<T?> _showGenericSelectionBottomSheet<T>({
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T?>(
      context: context,
      builder: (context) {
        return Theme(
          data: AppThemeData.modalScreen(context),
          child: Builder(
            builder: (context) {
              final appSizes = Theme.of(
                context,
              ).extension<AppSizesThemeExtension>()!;
              final appEffects = Theme.of(
                context,
              ).extension<AppEffectsThemeExtension>()!;

              return DraggableScrollableSheet(
                snap: true,
                minChildSize: appSizes.modalMinSnapSize,
                snapSizes: appSizes.modalSnapSizes,
                builder: (_, scrollController) {
                  final appColors = Theme.of(
                    context,
                  ).extension<AppColorsThemeExtension>()!;

                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Shapes.extraLarge),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: ClipRRect(
                            child: BackdropFilter(
                              filter: appEffects.modalBlurEffect,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: appColors.modalBackgroundColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(Shapes.extraLarge),
                                  ),
                                  border: Border.all(
                                    color: appColors.modalBorderColor,
                                    width: appSizes.borderSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Align(child: BottomSheetDragHandle()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 16.0,
                                ),
                                child: BottomSheetTitle(
                                  title: title,
                                  tooltipMessage: 'Salva e chiudi',
                                  icon: PhosphorIconsBold.check,
                                  onClose: () => Navigator.of(context).pop(),
                                ),
                              ),
                              ...children,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Shapes.extraLarge),
        ),
      ),
      constraints: const BoxConstraints(maxWidth: 720.0),
      isScrollControlled: true,
      useSafeArea: true,
    );
  }

  void _changeSelectedTypes(
    bool? value,
    ContentType type,
    void Function(void Function()) setState,
  ) => setState(() {
    final test = value ?? false;

    if (test) {
      _selectedTypes.add(type);
    } else {
      _selectedTypes.remove(type);
    }
  });

  void _changeSelectedCategories(
    bool? value,
    ContentCategory category,
    void Function(void Function()) setState,
  ) => setState(() {
    final test = value ?? false;

    if (test) {
      _selectedCategories.add(category);
    } else {
      _selectedCategories.remove(category);
    }
  });
}

class _SelectionWidget extends StatelessWidget {
  const _SelectionWidget({
    super.key,
    required this.isSelected,
    required this.onChanged,
  });

  final bool isSelected;
  final void Function(bool? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: isSelected,
      onChanged: onChanged,
      activeColor: context.appColors.modalBackgroundColor,
      checkColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      side: BorderSide(
        color: context.appColors.modalBorderColor,
        width: context.appSizes.borderSize,
      ),
    );
  }
}
