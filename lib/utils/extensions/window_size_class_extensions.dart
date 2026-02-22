import 'package:moliseis/utils/enums.dart';

extension WindowSizeClassExtensions on WindowSizeClass {
  bool get isCompact => this == WindowSizeClass.compact;
  bool get isMedium => this == WindowSizeClass.medium;
  bool get isExpanded => this == WindowSizeClass.expanded;
  bool get isLarge => this == WindowSizeClass.large;
  bool get isExtraLarge => this == WindowSizeClass.extraLarge;

  bool isLargerThan(WindowSizeClass other) => index > other.index;
  bool isSmallerThan(WindowSizeClass other) => index < other.index;
  // bool isEqualTo(WindowSizeClass other) => index == other.index;
  bool isAtLeast(WindowSizeClass other) => index >= other.index;
  bool isAtMost(WindowSizeClass other) => index <= other.index;

  double get spacing {
    if (isCompact) return 16.0;

    return 24.0;
  }
}
