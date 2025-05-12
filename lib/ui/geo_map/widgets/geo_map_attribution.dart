import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:provider/provider.dart';

class GeoMapAttribution extends StatelessWidget {
  const GeoMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8.0,
        runAlignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          UrlTextButton.icon(
            onPressed: () async {
              if (!await context.read<AppUrlLauncher>().mapTilerWebsite()) {
                if (context.mounted) {
                  showSnackBar(
                    context: context,
                    textContent:
                        'Si è verificato un errore, riprova più tardi.',
                  );
                }
              }
            },
            icon: const ImageIcon(
              AssetImage('assets/icon/maptiler-icon-dark_64x69_optimized.png'),
            ),
            iconSize: 24.0,
            label: const Text('© MapTiler'),
          ),
          UrlTextButton(
            onPressed: () async {
              if (!await context
                  .read<AppUrlLauncher>()
                  .openStreetMapWebsite()) {
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
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}
