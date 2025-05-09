part of 'gallery_preview_modal_overlay.dart';

class _GalleryPreviewModalOverlayContent extends StatelessWidget {
  const _GalleryPreviewModalOverlayContent({
    this.attractionName = '',
    this.title = '',
    this.author = '',
    this.license = '',
    this.licenseUrl = '',
    this.placeName,
    this.attractionId,
    this.onSharePressed,
  });

  final String? attractionName;
  final String? title;
  final String author;
  final String license;
  final String licenseUrl;
  final String? placeName;
  final int? attractionId;
  final void Function()? onSharePressed;

  @override
  Widget build(BuildContext context) {
    Widget? attractionTitleText;

    if (attractionName != null && attractionName!.isNotEmpty) {
      attractionTitleText = FlexTest(
        left: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            attractionName!,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        right: LinkTextButton(
          attractionId,
          onPressed: () {
            GoRouter.of(context).pop();
            GoRouter.of(context).goNamed(
              RouteNames.exploreStory,
              pathParameters: {'id': attractionId.toString()},
            );
          },
        ),
      );
    }

    Widget? imageTitleText;

    if (title != null && title!.isNotEmpty) {
      imageTitleText = Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          title!,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
        ),
      );
    }

    // TODO(xmattjus): find a nicer way to show the title of the image.
    imageTitleText = null;

    Widget? placeNameText;

    if (placeName != null && placeName!.isNotEmpty) {
      placeNameText = Padding(
        padding: EdgeInsetsDirectional.only(
          top: 4.0,
          bottom: imageTitleText != null ? 4.0 : 8.0,
        ),
        child: CustomRichText(
          Text(placeName!),
          icon: const Icon(Icons.place_outlined),
          labelTextStyle: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final copyrightOwnerText = TextSpan(
      text: 'Copyright © ${author.isNotEmpty ? author : 'Sconosciuto'}',
    );

    final licenseText = TextSpan(text: ' $license');

    final licenseButton = Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: UrlTextButton.icon(
        icon: const Icon(Icons.attribution),
        iconSize: 18.0,
        onPressed:
            licenseUrl.isNotEmpty
                ? () => context.read<AppUrlLauncher>().generic(licenseUrl)
                : null,
        label: Text.rich(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          TextSpan(children: <InlineSpan>[copyrightOwnerText, licenseText]),
        ),
        color: Theme.of(context).colorScheme.tertiaryFixedDim,
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomAppBar(
          title: Text('Anteprima'),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          showBackButton: true,
          backButtonBackground: Colors.transparent,
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Colors.black54, Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                16.0,
                16.0,
                0,
                16.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attractionTitleText != null) attractionTitleText,
                  if (placeNameText != null) placeNameText,
                  if (imageTitleText != null) imageTitleText,
                  licenseButton,
                  const SizedBox(height: 16.0),
                  ButtonList(
                    items: <Widget>[
                      ElevatedButton.icon(
                        onPressed: () => onSharePressed?.call(),
                        icon: const Icon(Icons.share),
                        label: const Text('Condividi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
