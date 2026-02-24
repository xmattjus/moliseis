import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:moliseis/ui/geo_map/widgets/components/map_attribution.dart';

class AnimatedMapAttribution extends StatefulWidget {
  final DraggableScrollableController controller;
  const AnimatedMapAttribution({super.key, required this.controller});

  @override
  State<AnimatedMapAttribution> createState() => _AnimatedMapAttributionState();
}

class _AnimatedMapAttributionState extends State<AnimatedMapAttribution> {
  DraggableScrollableController get _controller => widget.controller;

  final _positionAnimation = ValueNotifier<double>(0.35);

  double get _position => _positionAnimation.value;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_bottomSheetListener);
  }

  @override
  void dispose() {
    _controller.removeListener(_bottomSheetListener);
    _positionAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (context, child) {
        return SafeArea(
          // Prevents the widget from moving out of bounds when the bottom sheet
          // is completely closed.
          bottom: _position < 0.04,
          child: AnimatedSlide(
            offset: Offset(0, _position * -1.0),
            duration: Duration.zero,
            child: AnimatedOpacity(
              opacity: _position > 0.5 ? 0 : 1,
              curve: Curves.easeInOutCubicEmphasized,
              duration: Durations.medium3,
              child: child,
            ),
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: 8.0),
        child: MapAttribution(),
      ),
    );
  }

  void _bottomSheetListener() {
    // Clamps the widget movement on the X-axis to prevent it from moving out of
    // bounds when the bottom sheet is completely closed.
    if (_controller.isAttached) {
      Future.delayed(Duration.zero, () {
        if (context.mounted) {
          _positionAnimation.value = clampDouble(_controller.size, 0, 1.0);
        }
      });
    }
  }
}
