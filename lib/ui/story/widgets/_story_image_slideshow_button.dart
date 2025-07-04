part of 'story_image_slideshow.dart';

class _StoryImageSlideshowButton extends StatefulWidget {
  /// Creates an animated button that expands and shrinks based on [expand].
  const _StoryImageSlideshowButton({
    required this.onPressed,
    required this.expand,
    required this.tickerProvider,
  });

  /// The callback that is called when the button is pressed or otherwise
  /// activated.
  final void Function() onPressed;

  final bool expand;

  final TickerProvider tickerProvider;

  @override
  State<_StoryImageSlideshowButton> createState() =>
      _StoryImageSlideshowButtonState();
}

class _StoryImageSlideshowButtonState
    extends State<_StoryImageSlideshowButton> {
  late final AnimationController _animationController;

  late final Animation<Alignment> alignmentAnimation;

  /// Animates the text opacity while the button is expanding/shrinking.
  late final Animation<double> opacityAnimation;

  /// Animates the button width (expand/shrink) to accommodate for the text
  /// being shown or hidden.
  late final Animation<double> widthAnimation;

  late final Animation<double> paddingAnimation;

  final Interval defaultCurve = const Interval(
    0.000,
    1.000,
    curve: Curves.easeInOutCubicEmphasized,
  );

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Durations.medium4,
      vsync: widget.tickerProvider,
    );

    opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.400,
          0.900,
          curve: Curves.easeInOutCubicEmphasized,
        ),
      ),
    );

    paddingAnimation = Tween<double>(begin: 7.95, end: 16.0).animate(
      CurvedAnimation(parent: _animationController, curve: defaultCurve),
    );

    alignmentAnimation =
        Tween<Alignment>(
          begin: Alignment.center,
          end: Alignment.centerLeft,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    /// Calculates the button's text total width before rendering it on screen.
    final textSpan = TextSpan(
      text: 'Attiva scorrimento automatico',
      style: TextTheme.of(context).labelLarge,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: Directionality.of(context),
    );

    textPainter.layout();

    final iconTheme = IconTheme.of(context);

    /// The maximum button width depends on the global text and icon themes.
    ///
    /// The constants being added at the end are the default outlined button
    /// padding values per Material3 guidelines.
    widthAnimation =
        Tween<double>(
          begin: 40,
          end: textPainter.width + (iconTheme.size ?? 18.0) + 16.0 + 8.0 + 24.0,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );
  }

  @override
  void didUpdateWidget(covariant _StoryImageSlideshowButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// Animates the button on parent state changes.
    if (widget.expand != oldWidget.expand) {
      _handleAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Animates the button to its expanded or retracted state.
  void _handleAnimation() => widget.expand
      ? _animationController.forward()
      : _animationController.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController.view,
      builder: (_, _) {
        return SizedBox(
          width: widthAnimation.value,
          child: OutlinedButton.icon(
            onPressed: widget.onPressed,
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll<Color>(
                Colors.black38,
              ),
              foregroundColor: const WidgetStatePropertyAll<Color>(
                Colors.white,
              ),
              padding: WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.only(
                  left: paddingAnimation.value,
                  right: paddingAnimation.value - 8.0,
                ),
              ),
              iconColor: const WidgetStatePropertyAll<Color>(Colors.white),
              fixedSize: WidgetStatePropertyAll(
                Size(widthAnimation.value, 40.0),
              ),
              alignment: alignmentAnimation.value,
            ),
            icon: AnimatedIcon(
              icon: AnimatedIcons.pause_play,
              progress: _animationController,
            ),
            label: _animationController.isDismissed
                ? const SizedBox()
                : Opacity(
                    opacity: opacityAnimation.value,
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
