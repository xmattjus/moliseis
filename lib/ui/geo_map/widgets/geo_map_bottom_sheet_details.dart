import 'package:flutter/material.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/detail/widgets/detail_description.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class GeoMapBottomSheetDetails extends StatelessWidget {
  const GeoMapBottomSheetDetails(
    this.content, {
    required this.onCloseButtonPressed,
    required this.onNearContentPressed,
    required this.viewModel,
  });

  final ContentBase content;

  /// Called when the close button has been pressed or otherwise activated.
  final VoidCallback onCloseButtonPressed;

  final void Function(ContentBase content) onNearContentPressed;

  final GeoMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16.0,
            children: <Widget>[
              Expanded(
                child: ContentNameAndCity(
                  name: 'Esplora ${content.name}',
                  cityName: content.city.target?.name,
                  nameStyle: CustomTextStyles.title(context),
                  cityNameStyle: CustomTextStyles.subtitle(context),
                  overflow: TextOverflow.visible,
                ),
              ),
              Tooltip(
                message: 'Chiudi',
                child: RawMaterialButton(
                  onPressed: onCloseButtonPressed,
                  elevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  constraints: const BoxConstraints.expand(
                    width: 32,
                    height: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  child: const Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
        ),
        HorizontalButtonList(
          padding: const EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 0),
          items: <Widget>[
            FavouriteButton.wide(content: content),
            OutlinedButton.icon(
              onPressed: () async {
                if (!await context.read<UrlLaunchService>().openGoogleMaps(
                  content.name,
                  content.city.target?.name ?? 'Molise',
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
              icon: const Icon(Icons.directions),
              label: const Text('Indicazioni'),
            ),
            /*
              OutlinedButton.icon(
                onPressed: () {
                  // TODO(xmattjus): share deep link to this screen.
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Condividi'),
              ),
               */
          ],
        ),
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 0),
          child: TextSectionDivider('Immagini'),
        ),
        SizedBox(
          height: kGridViewCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(
              16.0,
              8.0,
              16.0,
              16.0,
            ),
            itemBuilder: (context, index) {
              return CardBase(
                elevation: 0,
                onPressed: () async {
                  const modal = GalleryPreviewModal();
                  await modal(
                    context: context,
                    images: content.media,
                    initialIndex: index,
                  );
                },
                child: CustomImage.network(
                  content.media[index].url,
                  width: kGridViewCardWidth,
                  height: kGridViewCardHeight,
                  imageWidth: content.media[index].width,
                  imageHeight: content.media[index].height,
                  fit: BoxFit.cover,
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(width: 8.0),
            itemCount: content.media.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DetailDescription(content: content),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: content.description.isNotEmpty ? 16.0 : 0,
          ),
          child: NearbyContentHorizontalList(
            coordinates: content.coordinates,
            onPressed: onNearContentPressed,
            loadNearContentCommand: viewModel.loadNearContent,
            nearContent: viewModel.nearContent,
          ),
        ),
      ],
    );
  }
}
