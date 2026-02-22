import 'package:flutter/material.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8.0,
          runAlignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            UrlTextButton.icon(
              onPressed: () async {
                if (!await context
                    .read<UrlLaunchService>()
                    .openMapTilerWebsite()) {
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      textContent:
                          'Si è verificato un errore, riprova più tardi.',
                    );
                  }
                }
              },
              icon: const ImageIcon(AssetImage(kAssetMapTilerIconPath)),
              iconSize: 24.0,
              label: const Text('© MapTiler'),
            ),
            UrlTextButton(
              onPressed: () async {
                if (!await context
                    .read<UrlLaunchService>()
                    .openOpenStreetMapWebsite()) {
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      textContent:
                          'Si è verificato un errore, riprova più tardi.',
                    );
                  }
                }
              },
              label: const Text('© OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}
