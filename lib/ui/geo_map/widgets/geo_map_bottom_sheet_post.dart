import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_close_button.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';
import 'package:moliseis/ui/post/widgets/components/post_title.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class GeoMapBottomSheetPost extends StatelessWidget {
  const GeoMapBottomSheetPost(
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
              PostTitle(content: content),
              AppBottomSheetCloseButton(onClose: onCloseButtonPressed),
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
        const TextSectionDivider(
          'Immagini',
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 0),
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
          child: PostDescription(content: content),
        ),
        NearbyContentHorizontalList(
          coordinates: content.coordinates,
          onPressed: onNearContentPressed,
          loadNearContentCommand: viewModel.loadNearContent,
          nearContent: viewModel.nearContent,
        ),
      ],
    );
  }
}
