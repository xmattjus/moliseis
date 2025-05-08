import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';

class StorySource extends StatelessWidget {
  const StorySource({super.key, required this.texts});

  final List<String> texts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8.0),
          child: Text('Fonti', style: CustomTextStyles.section(context)),
        ),
        ...texts.map((e) {
          return e.isValidUrl
              ? UrlTextButton.icon(
                label: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                icon: const Icon(Icons.link),
                iconSize: 18.0,
                onPressed: () async {
                  await context.read<AppUrlLauncher>().generic(e);
                },
                color: Theme.of(context).colorScheme.secondary,
              )
              : Text(
                e,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              );
        }),
      ],
    );
  }
}
