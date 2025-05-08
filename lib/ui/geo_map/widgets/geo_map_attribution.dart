import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:moliseis/utils/app_url_launcher.dart';

class GeoMapAttribution extends StatelessWidget {
  const GeoMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    ///
    final urlLauncher = AppUrlLauncher();

    return Align(
      alignment: Alignment.bottomRight,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8.0,
        children: <Widget>[
          UrlTextButton.icon(
            onPressed: () async {
              if (!await urlLauncher.mapTilerWebsite()) {
                debugPrint('Something went wrong');
              }
            },
            icon: const ImageIcon(
              AssetImage('assets/icon/maptiler-icon-dark_64x69_optimized.png'),
            ),
            iconSize: 24.0,
            label: const Text('© MapTiler'),
          ),
          // const Text('|'),
          UrlTextButton(
            onPressed: () async {
              if (!await urlLauncher.openStreetMapWebsite()) {
                debugPrint('Something went wrong');
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
