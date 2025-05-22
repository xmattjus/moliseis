part of 'geo_map_bottom_sheet.dart';

class _GoeMapBottomSheetDetails extends StatelessWidget {
  const _GoeMapBottomSheetDetails({
    required this.attractionId,
    required this.onCloseButtonTap,
    required this.onNearAttractionTap,
    required this.future,
  });

  /// The user selected attraction's local database id.
  final int attractionId;

  /// Called when the close button has been pressed or otherwise activated.
  final VoidCallback onCloseButtonTap;

  final void Function(int attractiondId) onNearAttractionTap;

  final Future<Attraction>? future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilt<Attraction>(
      future,
      onLoading: () {
        return const SliverToBoxAdapter(
          child: Center(child: CustomCircularProgressIndicator.withDelay()),
        );
      },
      onSuccess: (attraction) {
        Widget? summary;

        if (attraction.summary.isNotEmpty) {
          summary = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CustomRichText(
              const Text('In breve'),
              labelTextStyle: CustomTextStyles.section(context),
              content: Text(attraction.summary),
              maxLines: 2,
            ),
          );
        }

        return SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                16.0,
                18.0,
                16.0,
                4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16.0,
                children: [
                  Expanded(
                    child: Text(
                      'Esplora ${attraction.name}',
                      style: CustomTextStyles.title(context),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  Tooltip(
                    message: 'Chiudi',
                    child: RawMaterialButton(
                      onPressed: onCloseButtonTap,
                      elevation: 0.0,
                      focusElevation: 0.0,
                      hoverElevation: 0.0,
                      highlightElevation: 0.0,
                      constraints: const BoxConstraints.expand(
                        width: 32,
                        height: 32,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Pad(
              h: 16.0,
              child: CustomRichText(
                Text(attraction.place.target!.name),
                labelTextStyle: CustomTextStyles.subtitle(context),
                icon: const Icon(Icons.place_outlined),
              ),
            ),
            ButtonList(
              padding: const EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 0),
              items: <Widget>[
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!await context.read<AppUrlLauncher>().googleMaps(
                      attraction.name,
                      attraction.place.target?.name,
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
                FavouriteButton.wide(id: attraction.id),
              ],
            ),
            const Pad(t: 16.0, h: 16.0, child: TextSectionDivider('Immagini')),
            SizedBox(
              height: 200.0,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  16.0,
                  8.0,
                  16.0,
                  16.0,
                ),
                itemBuilder: (context, index) {
                  final mediaQuery = MediaQuery.maybeSizeOf(context);
                  final width = (mediaQuery?.width ?? 400.0) * 0.66;
                  return CardBase(
                    onPressed: () async {
                      const modal = GalleryPreviewModal();
                      await modal(
                        context: context,
                        images: attraction.images,
                        initialIndex: index,
                      );
                    },
                    child: CustomImage.network(
                      attraction.images[index].url,
                      width: width,
                      height: 200.0,
                      imageWidth: attraction.images[index].width.toDouble(),
                      imageHeight: attraction.images[index].height.toDouble(),
                      fit: BoxFit.cover,
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                itemCount: attraction.images.length,
              ),
            ),
            if (summary != null) summary,
            Align(
              alignment: Alignment.centerRight,
              child: LinkTextButton(
                onPressed: () {
                  GoRouter.of(context).goNamed(
                    RouteNames.exploreStory,
                    pathParameters: {'id': attraction.id.toString()},
                  );
                },
                label: const Text('Apri dettagli'),
              ),
            ),
            Pad(
              t: attraction.summary.isNotEmpty ? 16.0 : 0,
              child: NearAttractionsList(
                coordinates: <double>[
                  attraction.coordinates[0],
                  attraction.coordinates[1],
                ],
                hideFirstItem: true,
                onPressed: onNearAttractionTap,
              ),
            ),
          ],
        );
      },
      onError: (error) {
        return SliverToBoxAdapter(child: EmptyView.error(text: Text('$error')));
      },
    );
  }
}
