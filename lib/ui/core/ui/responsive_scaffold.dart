import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ResponsiveScaffold extends StatefulWidget {
  final DraggableScrollableController? draggableScrollableController;
  final ScrollableWidgetBuilder modalBuilder;
  final Widget child;

  const ResponsiveScaffold({
    super.key,
    this.draggableScrollableController,
    required this.modalBuilder,
    required this.child,
  });

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  /// Creates an internal scroll controller if it has not been provided.
  DraggableScrollableController? _internaldraggableScrollableController;
  DraggableScrollableController get _draggableScrollableController =>
      widget.draggableScrollableController ??
      (_internaldraggableScrollableController ??=
          DraggableScrollableController());
  late final ScrollController _internalScrollController;

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _internaldraggableScrollableController?.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowSizeClass = context.windowSizeClass;

    final showBottomSheet = windowSizeClass.isSmallerThan(
      WindowSizeClass.expanded,
    );

    final modalMaxWidth = windowSizeClass.isLargerThan(WindowSizeClass.expanded)
        ? 412.0
        : 360.0;

    if (!showBottomSheet) {
      return _InnerScaffold(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints.tightFor(width: modalMaxWidth),
                child: _DecoratedBox(
                  child: widget.modalBuilder(
                    context,
                    _internalScrollController,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: windowSizeClass.spacing,
                  ),
                  child: _DecoratedBox(child: widget.child),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _InnerScaffold(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(child: widget.child),
          AppBottomSheet(
            controller: _draggableScrollableController,
            builder: widget.modalBuilder,
          ),
        ],
      ),
    );
  }
}

class _InnerScaffold extends StatelessWidget {
  final Widget child;
  const _InnerScaffold({required this.child});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: SafeArea(bottom: false, child: child));
}

class _DecoratedBox extends StatelessWidget {
  final Widget child;
  const _DecoratedBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final appShapes = context.appShapes;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.paneColor,
        borderRadius: appShapes.circular.cornerExtraLarge,
      ),
      child: child,
    );
  }
}
