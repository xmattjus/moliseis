part of 'geo_map_bottom_sheet.dart';

class _GoeMapBottomSheetContent extends StatelessWidget {
  const _GoeMapBottomSheetContent({
    required this.attractionId,
    required this.currentMapCenter,
    required this.onNearAttractionTap,
    required this.onCloseButtonTap,
    required this.future,
  });

  /// The [Attraction] Id.
  ///
  /// When both [attractionId] and [currentMapCenter] are defined,
  /// [attractionId] will take priority, e.g. the details of that [Attraction]
  /// will be shown in the bottom sheet.
  final int attractionId;

  /// The current map center.
  ///
  /// When both [attractionId] and [currentMapCenter] are defined,
  /// [attractionId] will take priority, e.g. the details of that [Attraction]
  /// will be shown in the bottom sheet.
  final LatLng currentMapCenter;

  /// Returns the [Attraction] Id that has been tapped on.
  final void Function(int attractiondId) onNearAttractionTap;

  /// Called when the close button has been tapped on.
  final VoidCallback onCloseButtonTap;

  final Future<Attraction>? future;

  @override
  Widget build(BuildContext context) {
    final urlLauncher = AppUrlLauncher();

    if (attractionId == 0) {
      return SliverList.list(
        children: <Widget>[
          Pad(
            t: 8.0,
            b: 16.0,
            h: 16.0,
            child: Text(
              'Esplora i dintorni',
              style: CustomTextStyles.title(context),
              textAlign: Platform.isIOS ? TextAlign.center : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          NearAttractionsList(
            coordinates: <double>[
              currentMapCenter.latitude,
              currentMapCenter.longitude,
            ],
            onPressed: (id) {
              return onNearAttractionTap(id);
            },
          ),
        ],
      );
    }

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
              content: Text(attraction.summary).justify,
              maxLines: 2,
            ),
          );
        }

        return SliverList.list(
          children: [
            FlexTest(
              left: Pad(
                h: 16.0,
                v: 8.0,
                child: Text(
                  'Esplora ${attraction.name}',
                  style: CustomTextStyles.title(context),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                ),
              ),
              right: Pad(
                e: 8.0,
                child: IconButton.filledTonal(
                  iconSize: 16.0,
                  visualDensity: VisualDensity.compact,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                  ),
                  onPressed: () => onCloseButtonTap(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Chiudi',
                ),
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
                    await urlLauncher.googleMaps(
                      attraction.name,
                      attraction.place.target?.name,
                    );
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
            Pad(
              t: 16.0,
              h: 16.0,
              child: CustomRichText(
                const Text('Immagini'),
                labelTextStyle: CustomTextStyles.section(context),
              ),
            ),
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
                    child: CustomImage(
                      attraction.images[index],
                      width: width,
                      height: 200.0,
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
                }, label: const Text('Apri dettagli'),
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
                onPressed: (id) => onNearAttractionTap(id),
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
