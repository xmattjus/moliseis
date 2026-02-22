import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_surface.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppBottomSheet extends StatelessWidget {
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double>? snapSizes;
  final DraggableScrollableController? controller;
  final ScrollableWidgetBuilder builder;

  const AppBottomSheet({
    super.key,
    this.initialChildSize = 0.35,
    this.minChildSize = 0.2,
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
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snap: true,
        snapSizes: snapSizes ?? appSizes.modalSnapSizes,
        controller: controller,
        builder: (context, scrollController) {
          return AppBottomSheetSurface(
            child: builder(context, scrollController),
          );
        },
      ),
    );
  }
}
