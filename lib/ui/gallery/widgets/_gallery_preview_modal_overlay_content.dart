part of 'gallery_preview_modal_overlay.dart';

class _GalleryPreviewModalOverlayContent extends StatelessWidget {
  const _GalleryPreviewModalOverlayContent({
    required this.eventOrPlaceName,
    this.title = '',
    this.author = '',
    this.license = '',
    this.licenseUrl = '',
    required this.cityName,
    this.onSharePressed,
  });

  final String eventOrPlaceName;
  final String title;
  final String author;
  final String license;
  final String licenseUrl;
  final String cityName;
  final void Function()? onSharePressed;

  @override
  Widget build(BuildContext context) {
    final imageTitleText = title.isNotEmpty
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
        : const EmptyBox();

    final copyrightOwnerText = TextSpan(
      text: 'Copyright © ${author.isNotEmpty ? author : 'Sconosciuto'}',
    );

    final licenseText = TextSpan(text: ' $license');

    final licenseButton = Padding(
      padding: const EdgeInsetsDirectional.only(top: 8.0),
      child: UrlTextButton.icon(
        icon: const Icon(Symbols.attribution),
        iconSize: 18.0,
        onPressed: licenseUrl.isNotEmpty
            ? () async {
                if (!await context.read<UrlLaunchService>().launchGenericUrl(
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
      children: <Widget>[
        const CustomAppBar(
          title: Text('Anteprima'),
          showBackButton: true,
          backButtonBgColor: Colors.transparent,
        ),
        LinearGradientBackground(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
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
                children: <Widget>[
                  ContentNameAndCity(
                    name: eventOrPlaceName,
                    cityName: cityName,
                    overflow: TextOverflow.visible,
                  ),
                  imageTitleText,
                  licenseButton,
                  const SizedBox(height: 16.0),
                  HorizontalButtonList(
                    items: <Widget>[
                      ElevatedButton.icon(
                        onPressed: () => onSharePressed?.call(),
                        icon: const Icon(Symbols.share),
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
