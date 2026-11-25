import 'package:material_ui/material_ui.dart';

import 'typography_harness.dart';

/// Supplies the real theme and a constrained, scaled presentation slot.
Widget emptyViewGeometryHarness({
  required Widget child,
  double width = 320,
  double height = 216,
  double scale = 1,
  MediaQueryData? mediaQuery,
  TextDirection direction = TextDirection.ltr,
  TextTheme? typography,
  bool photoViewer = false,
}) => typographyHarness(
  overrides: typography,
  photoViewer: photoViewer,
  child: Builder(
    builder: (context) => MediaQuery(
      data:
          mediaQuery ??
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    ),
  ),
);

/// Frozen pre-change composition used to compare spacious rendered geometry.
class OriginalEmptyViewGeometry extends StatelessWidget {
  /// Keeps the oracle independent of the new scrolling implementation.
  const OriginalEmptyViewGeometry({
    required this.icon,
    required this.text,
    required this.action,
    super.key,
  });

  final Widget icon;
  final Widget text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: IconTheme.merge(
              data: const IconThemeData(size: 40, opticalSize: 80),
              child: icon,
            ),
          ),
          DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyLarge!,
            textAlign: TextAlign.center,
            child: text,
          ),
          action,
        ],
      ),
    ),
  );
}
