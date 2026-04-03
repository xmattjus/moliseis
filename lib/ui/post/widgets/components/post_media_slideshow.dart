import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/ui/core/ui/app_page_indicator.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

part '_post_media_slideshow_pause_button.dart';

class PostMediaSlideshow extends StatefulWidget {
  const PostMediaSlideshow({
    super.key,
    required this.height,
    required this.media,
    required this.visibilityNotifier,
  });

  final double height;
  final List<Media> media;

  /// A [ValueNotifier] that indicates whether the slideshow is visible or not.
  final ValueNotifier<bool> visibilityNotifier;

  @override
  State<PostMediaSlideshow> createState() => _PostMediaSlideshowState();
}

class _PostMediaSlideshowState extends State<PostMediaSlideshow>
    with TickerProviderStateMixin {
  static const _bottomChromeHeight = 40.0;
  static const _bottomChromeOffset = -4.0;
  static const _pageIndicatorBottomOffset = 8.0;
  static const _pauseButtonOffset = 16.0;
  static const _pauseButtonAdditionalBottomSpacing = 24.0;

  late final AnimationController _animationController;

  Duration _delta = Duration.zero;

  bool get _isSlideshowVisible => widget.visibilityNotifier.value;

  final _autoPlayEnabledNotifier = ValueNotifier<bool>(true);
  bool get _isAutoPlayEnabled => _autoPlayEnabledNotifier.value;

  final _isMediaLoadingNotifier = ValueNotifier<bool>(true);
  bool get _isMediaLoading => _isMediaLoadingNotifier.value;

  /// The duration required to automatically change slide.
  static const _durationToNextSlide = Duration(seconds: 5);

  Duration _elapsedTime = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  /// Creates a page controller showing the content media.
  final PageController _pageController = PageController();

  late Ticker _ticker;

  /// Whether [_ticker] must be initialized or not.
  bool get _initTicker => widget.media.length > 1;

  int _lastPage = 0;

  /// Whether the user has manually disabled the slideshow autoplay by scrolling or not.
  bool _userDisabledScroll = false;

  @override
  void initState() {
    super.initState();

    if (_initTicker) {
      // The ticker will be started when the first image has been loaded.
      _ticker = createTicker(_onTick);
    }

    _animationController = AnimationController(
      duration: _durationToNextSlide,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant PostMediaSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the user has manually disabled the slideshow autoplay, we don't want to
    // re-enable it when the widget updates.
    if (_userDisabledScroll) return;

    _syncAutoPlayWithVisibility();
  }

  @override
  void dispose() {
    if (_initTicker) _ticker.dispose();
    _pageController.dispose();
    _isMediaLoadingNotifier.dispose();
    _autoPlayEnabledNotifier.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _syncAutoPlayWithVisibility() {
    _autoPlayEnabledNotifier.value = _isSlideshowVisible;
    _isSlideshowVisible ? _startAutoPlay() : _stopAutoPlay();
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastElapsed > const Duration(milliseconds: 500)) {
      _delta = Duration.zero;
    }

    _elapsedTime = elapsed - _delta;

    if (_elapsedTime > _durationToNextSlide) {
      _animateToNextSlideLooped();

      _delta = elapsed;
    }

    _lastElapsed = elapsed;
  }

  void _toggleAutoScroll() {
    _autoPlayEnabledNotifier.value = !_autoPlayEnabledNotifier.value;

    _userDisabledScroll = !_userDisabledScroll;

    !_isAutoPlayEnabled ? _stopAutoPlay() : _startAutoPlay();
  }

  void _disableAutoPlayByUserScroll() {
    _autoPlayEnabledNotifier.value = false;
    _userDisabledScroll = true;
    _stopAutoPlay();
  }

  Future<void> _openGalleryPreview(int initialIndex) async {
    if (_isAutoPlayEnabled) {
      _stopAutoPlay();
    }

    final isDismissed = await GalleryPreviewModal.show(
      context: context,
      media: widget.media,
      initialIndex: initialIndex,
    );

    if ((isDismissed ?? true) && _isAutoPlayEnabled) {
      _startAutoPlay();
    }
  }

  void _onImageLoadingChanged(bool isLoading) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isMediaLoadingNotifier.value = isLoading;
    });

    if (_isAutoPlayEnabled) {
      isLoading ? _stopAutoPlay() : _startAutoPlay();
    }
  }

  Widget _buildMediaPager(BoxConstraints constraints) => SizedBox(
    width: constraints.maxWidth,
    height: widget.height,
    child: NotificationListener(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _disableAutoPlayByUserScroll();
        }
        return true;
      },
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (_) {
          if (_isAutoPlayEnabled) {
            _animationController.forward(from: 0);
          }
        },
        itemBuilder: (_, index) {
          return CardBase(
            shape: const RoundedRectangleBorder(),
            onPressed: () => _openGalleryPreview(index),
            child: AppNetworkImage(
              url: widget.media[index].url,
              width: constraints.maxWidth,
              height: widget.height,
              imageWidth: widget.media[index].width,
              imageHeight: widget.media[index].height,
              onImageLoading: _onImageLoadingChanged,
            ),
          );
        },
        itemCount: widget.media.length,
      ),
    ),
  );

  Widget _buildBottomChrome(BuildContext context, BoxConstraints constraints) =>
      Positioned(
        bottom: _bottomChromeOffset,
        child: Container(
          width: constraints.maxWidth,
          height: _bottomChromeHeight,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.appColors.modalBorderColor,
                width: context.appSizes.borderSide.medium,
              ),
            ),
            borderRadius: BorderRadius.only(
              topLeft: context.appShapes.circular.cornerExtraLarge.topLeft,
              topRight: context.appShapes.circular.cornerExtraLarge.topRight,
            ),
            color: context.colorScheme.surface,
          ),
        ),
      );

  Widget _buildPageIndicator(int itemCount) => Positioned(
    left: 0,
    right: 0,
    bottom: _bottomChromeHeight + _pageIndicatorBottomOffset,
    child: Center(
      child: AppPageIndicator(
        pageController: _pageController,
        itemCount: itemCount,
      ),
    ),
  );

  Widget _buildPauseButtonOverlay() => Positioned(
    bottom:
        _bottomChromeHeight +
        _pageIndicatorBottomOffset +
        _pauseButtonOffset +
        _pauseButtonAdditionalBottomSpacing,
    right: _pauseButtonOffset,
    child: AnimatedBuilder(
      animation: Listenable.merge([
        widget.visibilityNotifier,
        _autoPlayEnabledNotifier,
        _isMediaLoadingNotifier,
      ]),
      builder: (_, _) {
        return _PostMediaSlideshowPauseButton(
          onPressed: _isMediaLoading || !_isSlideshowVisible
              ? null
              : _toggleAutoScroll,
          expanded: !_isAutoPlayEnabled,
          tickerProvider: this,
        );
      },
    ),
  );

  void _startAutoPlay() {
    // Starts the slideshow autoplay only if there is more than 1 media to show
    // and the ticker is not already active.
    if (_initTicker && !_ticker.isActive) {
      _delta = Duration.zero;
      _ticker.start();
      _animationController.forward();
    }
  }

  void _stopAutoPlay() {
    if (_initTicker && _ticker.isActive) {
      _ticker.stop();
      _animationController.reset();
    }
  }

  void _animateToNextSlideLooped() {
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.toInt() ?? _lastPage;

      final nextPage = currentPage < widget.media.length - 1
          ? currentPage + 1
          : 0;

      _pageController.animateToPage(
        nextPage,
        duration: Durations.extralong4,
        curve: Curves.easeInOutCubicEmphasized,
      );

      _lastPage = nextPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            _buildMediaPager(constraints),
            _buildBottomChrome(context, constraints),
            if (_initTicker) _buildPageIndicator(widget.media.length),
            if (_initTicker) _buildPauseButtonOverlay(),
          ],
        );
      },
    );
  }
}
