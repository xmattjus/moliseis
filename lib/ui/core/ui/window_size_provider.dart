import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Enum representing different device classes based on screen width as per
/// Material 3 design specifications.
///
/// The device types follow Material 3 breakpoints:
/// - [compact]: < 600dp (phones in portrait)
/// - [medium]: 600-839dp (tablets in portrait, foldables in portrait)
/// - [expanded]: 840-1199dp (tablets in landscape, foldables in landscape)
/// - [large]: 1200-1599dp (desktops)
/// - [extraLarge]: ≥ 1600dp (large desktops, TVs)
enum DeviceType { compact, medium, expanded, large, extraLarge }

/// Data class containing window size information and device type classification.
///
/// This class provides information about the current window dimensions and
/// categorizes the device type based on Material 3 design breakpoints.
/// It uses the smaller dimension (width or height) to determine the device type,
/// ensuring consistent behavior across device orientations.
///
/// Example usage:
/// ```dart
/// final windowData = WindowSizeData.fromSize(MediaQuery.of(context).size);
/// if (windowData.isCompact) {
///   // Show mobile layout
/// } else if (windowData.isExpanded) {
///   // Show tablet layout
/// }
/// ```
@immutable
class WindowSizeData {
  /// Material 3 width ranges for each device class.
  static const double _compactWidthLimit = 600;
  static const double _mediumWidthLimit = 839;
  static const double _expandedWidthLimit = 1199;
  static const double _largeWidthLimit = 1599;
  static const double _extraLargeWidthLimit = double.infinity;

  /// The current window size in logical pixels.
  final Size size;

  /// The device type based on the smaller dimension of the screen.
  final DeviceType deviceType;

  /// Whether the device is classified as compact (< 600dp).
  ///
  /// Typically phones in portrait orientation.
  final bool isCompact;

  /// Whether the device is classified as medium (600-839dp).
  ///
  /// Typically tablets in portrait or foldables in portrait.
  final bool isMedium;

  /// Whether the device is classified as expanded (840-1199dp).
  ///
  /// Typically tablets in landscape or foldables in landscape.
  final bool isExpanded;

  /// Whether the device is classified as large (1200-1599dp).
  ///
  /// Typically desktop screens.
  final bool isLarge;

  /// Whether the device is classified as extra large (≥ 1600dp).
  ///
  /// Typically large desktop screens or TVs.
  final bool isExtraLarge;

  /// Creates a [WindowSizeData] with the given parameters.
  ///
  /// All parameters are required and immutable once set.
  const WindowSizeData({
    required this.size,
    required this.deviceType,
    required this.isCompact,
    required this.isMedium,
    required this.isExpanded,
    required this.isLarge,
    required this.isExtraLarge,
  });

  /// Factory constructor to create [WindowSizeData] from a [Size].
  ///
  /// Uses the smaller dimension (width or height) to determine the device type,
  /// ensuring consistent classification regardless of device orientation.
  ///
  /// [size] The window size to classify.
  factory WindowSizeData.fromSize(Size size) {
    // Use the smaller dimension to determine the device type.
    final width = math.min(size.width, size.height);

    DeviceType deviceType;
    bool isCompact = false;
    bool isMedium = false;
    bool isExpanded = false;
    bool isLarge = false;
    bool isExtraLarge = false;

    switch (width) {
      case < _compactWidthLimit:
        deviceType = DeviceType.compact;
        isCompact = true;
      case <= _mediumWidthLimit:
        deviceType = DeviceType.medium;
        isMedium = true;
      case <= _expandedWidthLimit:
        deviceType = DeviceType.expanded;
        isExpanded = true;
      case <= _largeWidthLimit:
        deviceType = DeviceType.large;
        isLarge = true;
      case <= _extraLargeWidthLimit:
        deviceType = DeviceType.extraLarge;
        isExtraLarge = true;
      default:
        deviceType = DeviceType.compact;
        isCompact = true;
    }

    return WindowSizeData(
      size: size,
      deviceType: deviceType,
      isCompact: isCompact,
      isMedium: isMedium,
      isExpanded: isExpanded,
      isLarge: isLarge,
      isExtraLarge: isExtraLarge,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowSizeData &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          deviceType == other.deviceType;

  @override
  int get hashCode => size.hashCode ^ deviceType.hashCode;

  @override
  String toString() {
    return 'WindowSizeData(size: $size, deviceType: $deviceType)';
  }
}

/// An [InheritedWidget] that provides [WindowSizeData] to its descendants.
///
/// This widget allows child widgets to access window size information and
/// device type classification without passing the data through constructor
/// parameters.
///
/// Use [WindowSizeProvider.of] to access the data from descendant widgets.
///
/// Example usage:
/// ```dart
/// WindowSizeProvider(
///   windowSizeData: WindowSizeData.fromSize(size),
///   child: MyApp(),
/// )
/// ```
class WindowSizeProvider extends InheritedWidget {
  /// Creates a [WindowSizeProvider] with the given [windowSizeData].
  ///
  /// The [windowSizeData] and [child] parameters are required.
  const WindowSizeProvider({
    super.key,
    required this.windowSizeData,
    required super.child,
  });

  /// The window size data to provide to descendants.
  final WindowSizeData windowSizeData;

  /// Retrieves the [WindowSizeData] from the nearest [WindowSizeProvider] ancestor.
  ///
  /// This method will throw an assertion error if no [WindowSizeProvider] is
  /// found in the widget tree. Use [maybeOf] if the provider might not exist.
  ///
  /// [context] The build context to search from.
  static WindowSizeData of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<WindowSizeProvider>();
    assert(provider != null, 'No WindowSizeProvider found in context');
    return provider!.windowSizeData;
  }

  /// Retrieves the [WindowSizeData] from the nearest [WindowSizeProvider] ancestor.
  ///
  /// Returns null if no [WindowSizeProvider] is found in the widget tree.
  /// Use [of] if you expect the provider to always exist.
  ///
  /// [context] The build context to search from.
  static WindowSizeData? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<WindowSizeProvider>();
    return provider?.windowSizeData;
  }

  @override
  bool updateShouldNotify(WindowSizeProvider oldWidget) {
    return windowSizeData != oldWidget.windowSizeData;
  }
}

/// A widget that automatically provides [WindowSizeData] based on layout constraints.
///
/// This widget uses a [LayoutBuilder] to determine the available space and
/// creates appropriate [WindowSizeData] based on the constraints. It's useful
/// when you want to automatically adapt to window size changes without manually
/// managing the [WindowSizeProvider].
///
/// Example usage:
/// ```dart
/// AutoWindowSizeProvider(
///   child: MaterialApp(
///     home: HomePage(),
///   ),
/// )
/// ```
class AutoWindowSizeProvider extends StatelessWidget {
  /// Creates an [AutoWindowSizeProvider] with the given [child].
  ///
  /// The [child] parameter is required.
  const AutoWindowSizeProvider({super.key, required this.child});

  /// The widget to provide window size data to.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final windowSizeData = WindowSizeData.fromSize(size);

        return WindowSizeProvider(windowSizeData: windowSizeData, child: child);
      },
    );
  }
}

/// A builder widget that provides [WindowSizeData] to its builder function.
///
/// This widget is useful when you need to build different UI based on the
/// current window size. It automatically retrieves the [WindowSizeData] from
/// the nearest [WindowSizeProvider] and passes it to the builder function.
///
/// Example usage:
/// ```dart
/// WindowSizeBuilder(
///   builder: (context, windowData) {
///     if (windowData.isCompact) {
///       return MobileLayout();
///     } else {
///       return DesktopLayout();
///     }
///   },
/// )
/// ```
class WindowSizeBuilder extends StatelessWidget {
  /// Creates a [WindowSizeBuilder] with the given [builder] function.
  ///
  /// The [builder] parameter is required and will be called with the current
  /// [BuildContext] and [WindowSizeData].
  const WindowSizeBuilder({super.key, required this.builder});

  /// The builder function that creates the widget based on window size data.
  ///
  /// Called with the current [BuildContext] and [WindowSizeData] whenever
  /// the window size changes.
  final Widget Function(BuildContext context, WindowSizeData windowSizeData)
  builder;

  @override
  Widget build(BuildContext context) {
    final windowSizeData = WindowSizeProvider.of(context);
    return builder(context, windowSizeData);
  }
}
