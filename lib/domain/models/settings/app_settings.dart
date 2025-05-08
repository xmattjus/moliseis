import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/settings/theme_brightness.dart';
import 'package:moliseis/domain/models/settings/theme_type.dart';
import 'package:objectbox/objectbox.dart';

/// The id this will always have during ObjectBox transactions.
const settingsId = 1;

@Entity()
class AppSettings {
  @Id(assignable: true)
  int id = settingsId;

  @Transient()
  ThemeType type;

  @Transient()
  ThemeBrightness brightness;

  @Transient()
  AttractionSort attractionSort;

  int? get dbMode {
    _assertThemeTypeEnumValues();

    return type.index;
  }

  set dbMode(int? value) {
    _assertThemeTypeEnumValues();

    if (value == null) {
      type = ThemeType.system;
    } else {
      type =
          value >= 0 && value < ThemeType.values.length
              ? ThemeType.values[value]
              : ThemeType.system;
    }
  }

  int? get dbBrightness {
    _assertThemeBrightnessEnumValues();

    return brightness.index;
  }

  set dbBrightness(int? value) {
    _assertThemeBrightnessEnumValues();

    if (value == null) {
      brightness = ThemeBrightness.system;
    } else {
      brightness =
          value >= 0 && value < ThemeBrightness.values.length
              ? ThemeBrightness.values[value]
              : ThemeBrightness.system;
    }
  }

  int? get dbAttractionSort {
    _assertAttractionSortEnumValues();

    return attractionSort.index;
  }

  set dbAttractionSort(int? value) {
    _assertAttractionSortEnumValues();

    if (value == null) {
      attractionSort = AttractionSort.byName;
    } else {
      attractionSort =
          value >= 0 && value < AttractionSort.values.length
              ? AttractionSort.values[value]
              : AttractionSort.byName;
    }
  }

  @Property(type: PropertyType.dateNano)
  final DateTime modifiedAt;

  final bool crashReporting;

  AppSettings({
    this.type = ThemeType.system,
    this.brightness = ThemeBrightness.system,
    this.attractionSort = AttractionSort.byName,
    required this.modifiedAt,
    this.crashReporting = true,
  });

  AppSettings copyWith({
    ThemeType? type,
    ThemeBrightness? brightness,
    AttractionSort? attractionSort,
    DateTime? modifiedAt,
    bool? crashReporting,
  }) {
    return AppSettings(
      type: type ?? this.type,
      brightness: brightness ?? this.brightness,
      attractionSort: attractionSort ?? this.attractionSort,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      crashReporting: crashReporting ?? this.crashReporting,
    );
  }

  void _assertThemeTypeEnumValues() {
    assert(ThemeType.system.index == 0);
    assert(ThemeType.app.index == 1);
  }

  void _assertThemeBrightnessEnumValues() {
    assert(ThemeBrightness.system.index == 0);
    assert(ThemeBrightness.light.index == 1);
    assert(ThemeBrightness.dark.index == 2);
  }

  void _assertAttractionSortEnumValues() {
    assert(AttractionSort.byName.index == 0);
    assert(AttractionSort.byDate.index == 1);
  }
}
