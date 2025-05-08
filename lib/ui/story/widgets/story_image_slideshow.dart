import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:moliseis/ui/story/widgets/mountains_path_painter.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';

part '_story_image_slideshow_button.dart';

class StoryImageSlideshow extends StatefulWidget {
  const StoryImageSlideshow({required this.images});

  final List<MolisImage> images;

  @override
  State<StoryImageSlideshow> createState() => _StoryImageSlideshowState();
}

class _StoryImageSlideshowState extends State<StoryImageSlideshow>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;

  late final Animation<Color?> _circularProgColorAnimation;

  final _circularProgNotifier = ValueNotifier<double>(0);
  double get _circularProgressValue => _circularProgNotifier.value;

  Duration _delta = Duration.zero;

  final _autoScrollNotifier = ValueNotifier<bool>(false);
  bool get _enableAutoScroll => !_autoScrollNotifier.value;

  /// The duration required to automatically change slide.
  static const _durationToNextSlide = Duration(seconds: 5);

  Duration _elapsedTime = Duration.zero;

  /// Creates a page controller showing the [Attraction]'s images.
  final PageController _pageController = PageController();

  Ticker? _ticker;

  @override
  void initState() {
    super.initState();

    if (widget.images.length > 1) {
      _ticker = createTicker((elapsed) {
        _elapsedTime = elapsed - _delta;

        if (_elapsedTime.inMilliseconds > _durationToNextSlide.inMilliseconds) {
          _animateToNextSlide();

          _delta = elapsed;
        }

        _circularProgNotifier.value =
            _elapsedTime.inMilliseconds / _durationToNextSlide.inMilliseconds;
      });
    }

    _animationController = AnimationController(
      duration: _durationToNextSlide,
      vsync: this,
    );

    _circularProgColorAnimation = ColorTween(
      begin: Colors.deepPurpleAccent,
      end: Colors.deepOrangeAccent,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ticker?.dispose();
    _pageController.dispose();
    _circularProgNotifier.dispose();
    _autoScrollNotifier.dispose();
    super.dispose();
  }

  void _animateToNextSlide() {
    if (_elapsedTime.inMilliseconds > _durationToNextSlide.inMilliseconds) {
      final currentPage = _pageController.page?.toInt();
      if (currentPage != null && _pageController.hasClients) {
        _pageController.animateToPage(
          currentPage < widget.images.length - 1 ? currentPage + 1 : 0,
          duration: Durations.extralong4,
          curve: Curves.easeInOutCubicEmphasized,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final widgetHeight =
        screenHeight *
        (context.isLandscape
            ? kStorySlideshowLandscapeHeightPerc
            : kStorySlideshowPortraitHeightPerc);
    final customPainterHeight =
        screenWidth *
        (context.isLandscape
            ? kStorySlideshowLandscapePainterHeightPerc
            : kStorySlideshowPortraitPainterHeightPerc);

    return Stack(
      children: <Widget>[
        SizedBox(
          width: screenWidth,
          height: widgetHeight,
          child: NotificationListener(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                _autoScrollNotifier.value = true;
                _stopAutoPlay();
                _circularProgNotifier.value = 0;
              }
              return true;
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (_) {
                if (_enableAutoScroll) {
                  _animationController.forward(from: 0);
                  _circularProgNotifier.value = 1;
                }
              },
              itemBuilder: (_, index) {
                return CardBase(
                  shape: const RoundedRectangleBorder(),
                  onPressed: () async {
                    if (_enableAutoScroll) {
                      _stopAutoPlay();
                    }

                    const modal = GalleryPreviewModal();
                    final isDismissed = await modal(
                      context: context,
                      images: widget.images,
                      initialIndex: index,
                    );

                    if (isDismissed ?? true) {
                      if (_enableAutoScroll) {
                        _startAutoPlay();
                      }
                    }
                  },
                  child: CustomImage(
                    widget.images[index],
                    width: screenWidth,
                    height: widgetHeight,
                    fit: BoxFit.cover,
                    onImageLoading: (isLoading) {
                      if (_enableAutoScroll) {
                        isLoading ? _stopAutoPlay() : _startAutoPlay();
                      }
                    },
                  ),
                );
              },
              itemCount: widget.images.length,
            ),
          ),
        ),
        Positioned(
          bottom: -2.0, // Hides the gap at the bottom of the CustomPainter
          child: CustomPaint(
            size: Size(screenWidth, customPainterHeight),
            painter: MountainsPathPainter(
              gradientBottomColor: Theme.of(context).colorScheme.surface,
              gradientTopColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        if (widget.images.length > 1)
          Positioned(
            bottom: customPainterHeight + 4.0,
            right: 8.0,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _autoScrollNotifier,
                  builder: (context, child) {
                    return _StoryImageSlideshowButton(
                      onPressed: () {
                        _autoScrollNotifier.value = !_autoScrollNotifier.value;

                        !_enableAutoScroll ? _stopAutoPlay() : _startAutoPlay();

                        _circularProgNotifier.value = 0;
                      },
                      expand: !_enableAutoScroll,
                      tickerProvider: this,
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _circularProgNotifier,
                  builder: (context, child) {
                    return Positioned(
                      left: -4.0,
                      child: IgnorePointer(
                        child: Visibility(
                          visible: _enableAutoScroll,
                          child: CircularProgressIndicator(
                            value: _circularProgressValue,
                            backgroundColor: Colors.white38,
                            valueColor: _circularProgColorAnimation,
                            trackGap: 0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _startAutoPlay() {
    if (_ticker != null && _ticker!.isActive == false) {
      _delta = Duration.zero;
      _ticker!.start();
      _animationController.forward();
    }
  }

  void _stopAutoPlay() {
    if (_ticker != null && _ticker!.isActive) {
      _ticker!.stop();
      _animationController.reset();
    }
  }
}
