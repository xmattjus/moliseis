import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/ui/explore/view_models/place_view_model.dart';
import 'package:moliseis/ui/gallery/view_models/gallery_view_model.dart';
import 'package:provider/provider.dart';

class BaseAttractionCard extends StatefulWidget {
  const BaseAttractionCard(
    this.attractionId, {
    super.key,
    this.height,
    this.color,
    this.placeholderColor,
    this.elevation,
    this.shape,
    required this.onLoading,
    this.onPressed,
    this.actions,
    required this.builder,
  });

  final int attractionId;

  /// See [CardBase.height].
  final double? height;

  /// See [CardBase.color].
  final Color? color;

  /// The card's background color while loading.
  final Color? placeholderColor;

  /// See [CardBase.elevation].
  final double? elevation;

  /// See [CardBase.shape].
  final ShapeBorder? shape;

  final Widget Function()? onLoading;

  /// See [CardBase.onPressed].
  final VoidCallback? onPressed;

  /// See [CardBase.actions].
  final List<Widget>? actions;

  final Widget Function(Attraction attraction, MolisImage image, Place place)
  builder;

  @override
  State<BaseAttractionCard> createState() => _BaseAttractionCardState();
}

class _BaseAttractionCardState extends State<BaseAttractionCard>
    with AutomaticKeepAliveClientMixin {
  late final AttractionViewModel _attractionViewModel;
  late final GalleryViewModel _galleryViewModel;
  late final PlaceViewModel _plateViewModel;

  Future<List> get _futures {
    return Future.wait([
      _attractionViewModel.getAttractionById('${widget.attractionId}'),
      _galleryViewModel.getHeroFromAttractionId(widget.attractionId),
      _plateViewModel.getPlaceFromAttractionId(widget.attractionId),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _attractionViewModel = context.read();
    _galleryViewModel = context.read();
    _plateViewModel = context.read();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return CardBase(
      height: widget.height,
      color: widget.color,
      elevation: widget.elevation,
      shape: widget.shape,
      onPressed: widget.onPressed,
      actions: widget.actions,
      child: FutureBuilt<List>(
        _futures,
        onLoading: widget.onLoading,
        onSuccess: (data) => _buildSuccess(
          attraction: data[0] as Attraction,
          image: data[1] as MolisImage,
          place: data[2] as Place,
        ),
        onError: (error) {
          logger.severe('', error);
          return const EmptyView.error(text: SizedBox());
        },
      ),
    );
  }

  Widget _buildSuccess({
    required Attraction attraction,
    required MolisImage image,
    required Place place,
  }) {
    return widget.builder(attraction, image, place);
  }

  @override
  bool get wantKeepAlive => true;
}
