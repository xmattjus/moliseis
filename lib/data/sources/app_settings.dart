import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
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
  ContentSort contentSort;

  int? get dbMode {
    _assertThemeTypeEnumValues();

    return type.index;
  }

  set dbMode(int? value) {
    _assertThemeTypeEnumValues();

    if (value == null) {
      type = ThemeType.system;
    } else {
      type = value >= 0 && value < ThemeType.values.length
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
      brightness = value >= 0 && value < ThemeBrightness.values.length
          ? ThemeBrightness.values[value]
          : ThemeBrightness.system;
    }
  }

  int? get dbContentSort {
    _assertContentSortEnumValues();

    return contentSort.index;
  }

  set dbContentSort(int? value) {
    _assertContentSortEnumValues();

    if (value == null) {
      contentSort = ContentSort.byName;
    } else {
      contentSort = value >= 0 && value < ContentSort.values.length
          ? ContentSort.values[value]
          : ContentSort.byName;
    }
  }

  @Property(type: PropertyType.dateNano)
  final DateTime? modifiedAt;

  final bool crashReporting;

  AppSettings({
    this.type = ThemeType.system,
    this.brightness = ThemeBrightness.system,
    this.contentSort = ContentSort.byName,
    this.modifiedAt,
    this.crashReporting = true,
  });

  AppSettings copyWith({
    ThemeType? type,
    ThemeBrightness? brightness,
    ContentSort? contentSort,
    DateTime? modifiedAt,
    bool? crashReporting,
  }) {
    return AppSettings(
      type: type ?? this.type,
      brightness: brightness ?? this.brightness,
      contentSort: contentSort ?? this.contentSort,
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

  void _assertContentSortEnumValues() {
    assert(ContentSort.byName.index == 0);
    assert(ContentSort.byDate.index == 1);
  }
}
