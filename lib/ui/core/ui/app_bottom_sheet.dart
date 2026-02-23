import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_surface.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppBottomSheet extends StatelessWidget {
  final double? initialChildSize;
  final double? minChildSize;
  final double maxChildSize;
  final List<double>? snapSizes;
  final DraggableScrollableController? controller;
  final ScrollableWidgetBuilder builder;

  const AppBottomSheet({
    super.key,
    this.initialChildSize,
    this.minChildSize,
    this.maxChildSize = 1.0,
    this.snapSizes,
    this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final appSizes = context.appSizes;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: appSizes.bottomSheetMaxWidth),
      child: DraggableScrollableSheet(
        initialChildSize:
            initialChildSize ?? appSizes.bottomSheetInitialSnapSize,
        minChildSize: minChildSize ?? appSizes.bottomSheetMinSnapSize,
        maxChildSize: maxChildSize,
        snap: true,
        snapSizes: snapSizes ?? appSizes.bottomSheetSnapSizes,
        controller: controller,
        builder: (context, scrollController) =>
            AppBottomSheetSurface(child: builder(context, scrollController)),
      ),
    );
  }
}
