import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/services.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/category/widgets/category_button.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/post/widgets/components/animated_post_event_dates.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';
import 'package:moliseis/ui/post/widgets/components/post_geo_map_preview.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:moliseis/ui/post/widgets/components/post_title.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/weather_forecast_button.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

const double _mediaSlideshowHeight = 450.0;

class PostInnerScreen extends StatefulWidget {
  const PostInnerScreen({
    super.key,
    required this.content,
    required this.onContentPressed,
    required this.onCategoryPressed,
    this.onMapPressed,
    required this.loadNearContent,
    required this.nearContent,
    required this.weatherViewModel,
  });

  final ContentBase content;
  final void Function(ContentBase content) onContentPressed;
  final void Function() onCategoryPressed;
  final void Function()? onMapPressed;
  final Command1<void, LatLng> loadNearContent;
  final List<ContentBase> nearContent;
  final WeatherViewModel weatherViewModel;

  @override
  State<PostInnerScreen> createState() => _PostInnerScreenState();
}

class _PostInnerScreenState extends State<PostInnerScreen> {
  final ScrollController _scrollController = ScrollController();

  /// The scroll threshold at which the slideshow autoplay will be disabled.
  final double _enableSlideshowScollThreshold = _mediaSlideshowHeight * 0.6;

  /// Notifies its listeners of slideshow autoplay state changes.
  final _slideshowValueNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _slideshowValueNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_scrollController.position.pixels > _enableSlideshowScollThreshold) {
      _slideshowValueNotifier.value = false;
    } else if (_scrollController.position.pixels <=
        _enableSlideshowScollThreshold) {
      _slideshowValueNotifier.value = true;
    }

    // Returning false allows the notification to continue
    // bubbling up to ancestor listeners.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _slideshowValueNotifier,
              builder: (context, child) {
                return PostMediaSlideshow(
                  height: _mediaSlideshowHeight,
                  media: widget.content.media,
                  visibilityNotifier: _slideshowValueNotifier,
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16.0,
                children: [
                  PostTitle(content: widget.content),
                  WeatherForecastButton(
                    content: widget.content,
                    coordinates: widget.content.coordinates,
                    viewModel: widget.weatherViewModel,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: HorizontalButtonList(
              padding: const EdgeInsets.all(16.0),
              items: <Widget>[
                CategoryButton(
                  onPressed: widget.onCategoryPressed,
                  contentCategory: widget.content.category,
                ),
                FavouriteButton.wide(content: widget.content),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!await context.read<UrlLaunchService>().openGoogleMaps(
                      widget.content.name,
                      widget.content.city.target?.name ?? 'Molise',
                    )) {
                      if (context.mounted) {
                        showSnackBar(
                          context: context,
                          textContent:
                              'Si è verificato un errore, riprova più tardi.',
                        );
                      }
                    }
                  },
                  icon: const Icon(Symbols.directions),
                  label: const Text('Indicazioni'),
                ),
                /*
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO (xmattjus): share deep link to this screen.
                  },
                  icon: const Icon(Symbols.share),
                  label: const Text('Condividi'),
                ),
                */
              ],
            ),
          ),
          if (widget.content is EventContent)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(
                child: AnimatedPostEventDates(
                  event: widget.content as EventContent,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: PostDescription.sliver(content: widget.content),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 16.0),
            sliver: SliverList.list(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 16.0,
                  children: [
                    Text('Mappa', style: AppTextStyles.section(context)),
                    OutlinedButton.icon(
                      onPressed: widget.onMapPressed,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Symbols.explore),
                      label: const Text('Apri mappa'),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                PostGeoMapPreview(content: widget.content),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: NearbyContentHorizontalList(
              coordinates: widget.content.coordinates,
              onPressed: (content) => widget.onContentPressed(content),
              loadNearContentCommand: widget.loadNearContent,
              nearContent: widget.nearContent,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: context.bottomPadding),
          ),
        ],
      ),
    );
  }
}
