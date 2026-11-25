import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/core/ui/app_page_indicator.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/media/image_size_bucket.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

part '_post_media_slideshow_pause_button.dart';

class PostMediaSlideshow extends StatefulWidget {
  const PostMediaSlideshow({
    required this.height,
    required this.media,
    required this.visibilityNotifier,
    super.key,
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
  static const _innerChromeOffset = 16.0;
  static const _durationToNextSlide = Duration(seconds: 5);

  late final Ticker _ticker;
  final PageController _pageController = PageController();
  final _autoPlayEnabledNotifier = ValueNotifier<bool>(true);
  List<_MediaPageOwner> _owners = [];
  Object _listRevision = Object();
  int _activeIndex = 0;
  bool _userDisabledScroll = false;
  GalleryPresentation? _galleryPresentation;
  bool _publicationQueued = false;
  Duration _lastElapsed = Duration.zero;

  bool get _hasMultipleMedia => _owners.length > 1;
  bool get _isSlideshowVisible => widget.visibilityNotifier.value;
  bool get _isAutoPlayEnabled => _autoPlayEnabledNotifier.value;
  bool get _isMediaLoading => _owners.isEmpty || !_owners[_activeIndex].isReady;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.visibilityNotifier.addListener(_onVisibilityChanged);
    _reconcileOwners();
  }

  @override
  void didUpdateWidget(covariant PostMediaSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibilityNotifier != widget.visibilityNotifier) {
      oldWidget.visibilityNotifier.removeListener(_onVisibilityChanged);
      widget.visibilityNotifier.addListener(_onVisibilityChanged);
      // Reconcile after build, when request invalidation has been applied.
      _queuePublication();
    }
    // Owner and request changes queue their own deferred publication.
    _reconcileOwners();
  }

  void _reconcileOwners() {
    final identities = [
      for (final media in widget.media) (media.remoteId, media.url),
    ];
    var changed = identities.length != _owners.length;
    final next = <_MediaPageOwner>[];
    for (var i = 0; i < identities.length; i++) {
      if (i < _owners.length && _owners[i].identity == identities[i]) {
        next.add(_owners[i]);
      } else {
        changed = true;
        next.add(_MediaPageOwner(identities[i]));
      }
    }
    for (final owner in _owners) {
      if (!next.contains(owner)) owner.revoke();
    }
    _owners = next;
    if (!changed) return;
    _listRevision = Object();
    _activeIndex = _owners.isEmpty
        ? 0
        : _activeIndex.clamp(0, _owners.length - 1);
    _stopAutoPlay();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients && _owners.isNotEmpty) {
        _pageController.jumpToPage(_activeIndex);
      }
      _queuePublication();
    });
  }

  @override
  void dispose() {
    widget.visibilityNotifier.removeListener(_onVisibilityChanged);
    for (final owner in _owners) {
      owner.revoke();
    }
    _galleryPresentation?.detach();
    _ticker.dispose();
    _pageController.dispose();
    _autoPlayEnabledNotifier.dispose();
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    _reconcileAutoPlay();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (!_canAutoPlay) {
      _stopAutoPlay();
      return;
    }
    if (elapsed - _lastElapsed > _durationToNextSlide) {
      _lastElapsed = elapsed;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          (_activeIndex + 1) % _owners.length,
          duration: Durations.extralong4,
          curve: Curves.easeInOutCubicEmphasized,
        );
      }
    }
  }

  bool get _canAutoPlay =>
      mounted &&
      _hasMultipleMedia &&
      _isSlideshowVisible &&
      _isAutoPlayEnabled &&
      _galleryPresentation == null &&
      !_isMediaLoading;

  void _reconcileAutoPlay() {
    if (_canAutoPlay) {
      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    } else {
      _stopAutoPlay();
    }
  }

  void _stopAutoPlay() {
    if (_ticker.isActive) _ticker.stop();
  }

  void _toggleAutoScroll() {
    if (!mounted) return;
    _userDisabledScroll = !_userDisabledScroll;
    _autoPlayEnabledNotifier.value = !_userDisabledScroll;
    _reconcileAutoPlay();
  }

  void _disableAutoPlayByUserScroll() {
    _autoPlayEnabledNotifier.value = false;
    _userDisabledScroll = true;
    _stopAutoPlay();
  }

  Future<void> _openGalleryPreview(_MediaPageOwner owner) async {
    if (!mounted) return;
    if (_galleryPresentation != null || !owner.valid) return;
    final initialIndex = _owners.indexOf(owner);
    if (initialIndex < 0) return;
    late final GalleryPresentation presentation;
    presentation = GalleryPresentation(() {
      if (!mounted || !identical(_galleryPresentation, presentation)) return;
      _galleryPresentation = null;
      _reconcileAutoPlay();
    });
    _galleryPresentation = presentation;
    _stopAutoPlay();
    await GalleryPreviewScreen.show(
      context: context,
      media: widget.media,
      initialIndex: initialIndex,
      presentation: presentation,
    );
  }

  void _queuePublication() {
    if (!mounted) return;
    // Child build/disposal can publish; defer UI notification, then read the
    // latest active owner instead of retaining a page's obsolete loading bool.
    if (_publicationQueued) return;
    _publicationQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publicationQueued = false;
      setState(() {});
      _reconcileAutoPlay();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Widget _buildMediaPager(BoxConstraints constraints, Object request) {
    final revision = _listRevision;
    return SizedBox(
      width: constraints.maxWidth,
      height: widget.height,
      child: NotificationListener(
        onNotification: (notification) {
          if (!mounted) return true;
          if (notification is UserScrollNotification) {
            _disableAutoPlayByUserScroll();
          }
          return true;
        },
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            if (!mounted) return;
            if (!identical(revision, _listRevision) ||
                index >= _owners.length) {
              return;
            }
            _activeIndex = index;
            _stopAutoPlay();
            _queuePublication();
          },
          itemBuilder: (_, index) {
            final owner = _owners[index];
            return _SlideshowImagePage(
              key: ObjectKey(owner),
              owner: owner,
              request: request,
              width: constraints.maxWidth,
              height: widget.height,
              onChanged: _queuePublication,
              onPressed: () => _openGalleryPreview(owner),
            );
          },
          itemCount: _owners.length,
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int itemCount) => Positioned(
    left: 0,
    right: 0,
    bottom: _innerChromeOffset,
    child: Center(
      child: AppPageIndicator(
        pageController: _pageController,
        itemCount: itemCount,
      ),
    ),
  );

  Widget _buildPauseButtonOverlay() => Positioned(
    top: _innerChromeOffset,
    right: _innerChromeOffset,
    child: AnimatedBuilder(
      animation: Listenable.merge([
        widget.visibilityNotifier,
        _autoPlayEnabledNotifier,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final request = (
          ImageSizeBucket.resolveAndClamp(
            logicalWidth: constraints.maxWidth,
            logicalHeight: widget.height,
            devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 2,
          ),
          context.read<CacheManager>(),
        );
        var requestChanged = false;
        for (final owner in _owners) {
          if (owner.request != request) {
            requestChanged = true;
            owner
              ..request = request
              ..child = null
              ..loading = true;
          }
        }
        if (requestChanged) _queuePublication();
        return Stack(
          children: <Widget>[
            _buildMediaPager(constraints, request),
            if (_hasMultipleMedia) _buildPageIndicator(_owners.length),
            if (_hasMultipleMedia) _buildPauseButtonOverlay(),
          ],
        );
      },
    );
  }
}

/// Slot identity survives rebuilds; readiness belongs only to its live child.
class _MediaPageOwner {
  _MediaPageOwner(this.identity);

  final (int, String) identity;
  bool valid = true;
  bool loading = true;
  Object? child;
  Object? request;

  bool get isReady => valid && child != null && !loading;

  void revoke() {
    valid = false;
    child = null;
    loading = true;
  }
}

class _SlideshowImagePage extends StatefulWidget {
  const _SlideshowImagePage({
    required this.owner,
    required this.request,
    required this.width,
    required this.height,
    required this.onChanged,
    required this.onPressed,
    super.key,
  });

  final _MediaPageOwner owner;
  final Object request;
  final double width;
  final double height;
  final VoidCallback onChanged;
  final VoidCallback onPressed;

  @override
  State<_SlideshowImagePage> createState() => _SlideshowImagePageState();
}

class _SlideshowImagePageState extends State<_SlideshowImagePage> {
  Object _lease = Object();
  late ValueChanged<bool> _onImageLoading;

  void _bindRequest() {
    final owner = widget.owner;
    final request = widget.request;
    final lease = _lease = Object();
    owner
      ..child = lease
      ..loading = true;
    _onImageLoading = (loading) {
      if (!mounted) return;
      if (!owner.valid ||
          !identical(owner.child, lease) ||
          owner.request != request) {
        return;
      }
      owner.loading = loading;
      widget.onChanged();
    };
  }

  @override
  void initState() {
    super.initState();
    _bindRequest();
  }

  @override
  void didUpdateWidget(covariant _SlideshowImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) _bindRequest();
  }

  @override
  void dispose() {
    if (identical(widget.owner.child, _lease)) {
      widget.owner.child = null;
      widget.owner.loading = true;
      widget.onChanged();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CardBase(
    shape: const RoundedRectangleBorder(),
    onPressed: widget.onPressed,
    child: AppNetworkImage(
      url: widget.owner.identity.$2,
      width: widget.width,
      height: widget.height,
      onImageLoading: _onImageLoading,
    ),
  );
}
