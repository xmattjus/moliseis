import 'package:flutter/material.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/link_text_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runAlignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            LinkTextButton.icon(
              onPressed: () async {
                if (!await context
                    .read<UrlLaunchService>()
                    .openMapTilerWebsite()) {
                  if (context.mounted) {
                    _showSnackBar(context);
                  }
                }
              },
              icon: const ImageIcon(AssetImage(kAssetMapTilerIconPath)),
              iconSize: 24,
              label: const Text('© MapTiler'),
            ),
            LinkTextButton(
              onPressed: () async {
                if (!await context
                    .read<UrlLaunchService>()
                    .openOpenStreetMapWebsite()) {
                  if (context.mounted) {
                    _showSnackBar(context);
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

  void _showSnackBar(BuildContext context) => showSnackBar(
    context: context,
    textContent: 'Si è verificato un errore, riprova più tardi',
    type: SnackBarType.error,
  );
}
