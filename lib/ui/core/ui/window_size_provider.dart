import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Enum representing different device types based on screen width
enum DeviceType { mobile, tablet, tabletLarge, desktop }

/// Data class containing window size information
@immutable
class WindowSizeData {
  static const double _maxMobileWidth = 600;
  static const double _maxTabletWidth = 900;
  static const double _maxTabletXlWidth = 1200;

  /// The current window size
  final Size size;

  /// The device type based on screen width
  final DeviceType deviceType;

  /// Whether the device is mobile (width < [_maxMobileWidth])
  final bool isMobile;

  /// Whether the device is tablet (width >= [_maxMobileWidth] &&
  /// width < [_maxTabletWidth])
  final bool isTablet;

  /// Whether the device is large tablet (width >= [_maxTabletWidth] &&
  /// width < [_maxTabletXlWidth])
  final bool isTabletLarge;

  /// Whether the device is desktop (width >= [_maxTabletXlWidth])
  final bool isDesktop;

  const WindowSizeData({
    required this.size,
    required this.deviceType,
    required this.isMobile,
    required this.isTablet,
    required this.isTabletLarge,
    required this.isDesktop,
  });

  /// Factory constructor to create WindowSizeData from a Size
  factory WindowSizeData.fromSize(Size size) {
    // Use the smaller dimension to determine the device type.
    final width = math.min(size.width, size.height);

    DeviceType deviceType;
    bool isMobile = false;
    bool isTablet = false;
    bool isTabletLarge = false;
    bool isDesktop = false;

    switch (width) {
      case > _maxTabletXlWidth:
        deviceType = DeviceType.desktop;
        isDesktop = true;
      case > _maxTabletWidth:
        deviceType = DeviceType.tabletLarge;
        isTabletLarge = true;
      case > _maxMobileWidth:
        deviceType = DeviceType.tablet;
        isTablet = true;
      default:
        deviceType = DeviceType.mobile;
        isMobile = true;
    }

    return WindowSizeData(
      size: size,
      deviceType: deviceType,
      isMobile: isMobile,
      isTablet: isTablet,
      isTabletLarge: isTabletLarge,
      isDesktop: isDesktop,
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

/// Inherited widget that provides window size information to child widgets
class WindowSizeProvider extends InheritedWidget {
  const WindowSizeProvider({
    super.key,
    required this.windowSizeData,
    required super.child,
  });

  final WindowSizeData windowSizeData;

  /// Gets the WindowSizeData from the nearest WindowSizeProvider ancestor
  static WindowSizeData of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<WindowSizeProvider>();
    assert(provider != null, 'No WindowSizeProvider found in context');
    return provider!.windowSizeData;
  }

  /// Gets the WindowSizeData from the nearest WindowSizeProvider ancestor or null if not found
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

/// A widget that automatically provides window size information to its descendants
class AutoWindowSizeProvider extends StatelessWidget {
  const AutoWindowSizeProvider({super.key, required this.child});

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

/// A builder widget that rebuilds when window size changes
class WindowSizeBuilder extends StatelessWidget {
  const WindowSizeBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, WindowSizeData windowSizeData)
  builder;

  @override
  Widget build(BuildContext context) {
    final windowSizeData = WindowSizeProvider.of(context);
    return builder(context, windowSizeData);
  }
}
