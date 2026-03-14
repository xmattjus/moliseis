part of 'post_media_slideshow.dart';

class _PostMediaSlideshowPauseButton extends StatefulWidget {
  /// Creates an animated button that expands and shrinks based on [expanded].
  const _PostMediaSlideshowPauseButton({
    required this.onPressed,
    required this.expanded,
    required this.tickerProvider,
  });

  /// Called when the button is tapped or otherwise activated.
  ///
  /// If this callback is null, then the button will be disabled.
  final void Function()? onPressed;

  /// Whether the button is in its expanded state or not.
  final bool expanded;
  final TickerProvider tickerProvider;

  @override
  State<_PostMediaSlideshowPauseButton> createState() =>
      _PostMediaSlideshowPauseButtonState();
}

class _PostMediaSlideshowPauseButtonState
    extends State<_PostMediaSlideshowPauseButton> {
  late final AnimationController _animationController;

  /// Animates the button alignment from center to left when expanding.
  late final Animation<Alignment> _alignmentAnimation;

  /// Animates the text opacity while the button is expanding/shrinking.
  late final Animation<double> _opacityAnimation;

  /// Animates the button width (expand/shrink) to accommodate the text length.
  late Animation<double> _widthAnimation;

  late final Animation<double> _paddingAnimation;

  CurvedAnimation get _defaultCurved => CurvedAnimation(
    parent: _animationController,
    curve: const Interval(0.000, 1.000, curve: Curves.easeInOutCubicEmphasized),
  );

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Durations.medium4,
      vsync: widget.tickerProvider,
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.400,
          0.900,
          curve: Curves.easeInOutCubicEmphasized,
        ),
      ),
    );

    _paddingAnimation = Tween<double>(
      begin: 7.95,
      end: 16.0,
    ).animate(_defaultCurved);

    _alignmentAnimation = Tween<Alignment>(
      begin: Alignment.center,
      end: Alignment.centerLeft,
    ).animate(_defaultCurved);
  }

  double _calculateTextWidth(String text) {
    // Calculates the button's text total width before rendering it on screen.
    final textSpan = TextSpan(
      text: text,
      style: TextTheme.of(context).labelLarge,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: Directionality.of(context),
    );

    textPainter.layout();

    return textPainter.width;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final iconTheme = IconTheme.of(context);

    final textWidth = _calculateTextWidth('Attiva scorrimento automatico');

    // The maximum button width depends on the global text and icon themes.
    //
    // The constants being added at the end are the default outlined button
    // padding values per Material3 guidelines.
    _widthAnimation = Tween<double>(
      begin: 40.0,
      end: textWidth + (iconTheme.size ?? 18.0) + 16.0 + 8.0 + 24.0,
    ).animate(_defaultCurved);
  }

  @override
  void didUpdateWidget(covariant _PostMediaSlideshowPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.expanded != oldWidget.expanded) {
      /// Animates the button to its expanded or shrunk state.
      widget.expanded
          ? _animationController.forward()
          : _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.colorScheme.secondaryContainer;
    final foregroundColor = context.colorScheme.onSecondaryContainer;

    return AnimatedBuilder(
      animation: _animationController.view,
      builder: (_, _) {
        return SizedBox(
          width: _widthAnimation.value,
          child: FilledButton.tonalIcon(
            onPressed: widget.onPressed,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return backgroundColor.withValues(alpha: 0.45);
                }

                return backgroundColor;
              }),
              foregroundColor: WidgetStatePropertyAll<Color>(foregroundColor),
              padding: WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.only(
                  left: _paddingAnimation.value,
                  right: _paddingAnimation.value - 8.0,
                ),
              ),
              iconColor: WidgetStatePropertyAll<Color>(foregroundColor),
              fixedSize: WidgetStatePropertyAll(
                Size(_widthAnimation.value, 40.0),
              ),
              alignment: _alignmentAnimation.value,
            ),
            icon: AnimatedIcon(
              icon: AnimatedIcons.pause_play,
              progress: _animationController,
            ),
            label: _animationController.isDismissed
                ? const EmptyBox()
                : Opacity(
                    opacity: _opacityAnimation.value,
                    child: const Text(
                      'Attiva scorrimento automatico',
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
