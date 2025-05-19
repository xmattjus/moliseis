part of 'gallery_preview_modal_overlay.dart';

class _GalleryPreviewModalOverlayContent extends StatelessWidget {
  const _GalleryPreviewModalOverlayContent({
    required this.attractionName,
    this.title = '',
    this.author = '',
    this.license = '',
    this.licenseUrl = '',
    required this.placeName,
    this.attractionId = 0,
    this.onSharePressed,
  });

  final String attractionName;
  final String title;
  final String author;
  final String license;
  final String licenseUrl;
  final String placeName;
  final int attractionId;
  final void Function()? onSharePressed;

  @override
  Widget build(BuildContext context) {
    final attractionAndPlaceTitles = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4.0,
            children: [
              Text(
                attractionName,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              CustomRichText(
                Text(placeName),
                icon: const Icon(Icons.place_outlined),
                labelTextStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        // TODO(xmattjus): open a bottom sheet instead of changing screen.
        /*
        LinkTextButton(
          onPressed: () {
            GoRouter.of(context).pop();
            GoRouter.of(context).goNamed(
              RouteNames.homeStory,
              pathParameters: {'id': attractionId.toString()},
            );
          },
          label: const Text('Apri dettagli'),
        ),
         */
      ],
    );

    final imageTitleText =
        title.isNotEmpty
            ? Padding(
              padding: const EdgeInsetsDirectional.only(top: 8.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.9),
                ),
                overflow: TextOverflow.visible,
              ),
            )
            : const SizedBox();

    final copyrightOwnerText = TextSpan(
      text: 'Copyright © ${author.isNotEmpty ? author : 'Sconosciuto'}',
    );

    final licenseText = TextSpan(text: ' $license');

    final licenseButton = Padding(
      padding: const EdgeInsetsDirectional.only(top: 8.0),
      child: UrlTextButton.icon(
        icon: const Icon(Icons.attribution),
        iconSize: 18.0,
        onPressed:
            licenseUrl.isNotEmpty
                ? () async {
                  if (!await context.read<AppUrlLauncher>().generic(
                    licenseUrl,
                  )) {
                    if (context.mounted) {
                      showSnackBar(
                        context: context,
                        textContent:
                            'Si è verificato un errore, riprova più tardi.',
                      );
                    }
                  }
                }
                : null,
        label: Text.rich(
          TextSpan(children: <InlineSpan>[copyrightOwnerText, licenseText]),
          overflow: TextOverflow.ellipsis,
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
          backButtonBgColor: Colors.transparent,
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
                0.0,
                16.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  attractionAndPlaceTitles,
                  imageTitleText,
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
