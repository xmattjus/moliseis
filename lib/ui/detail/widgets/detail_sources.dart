import 'package:flutter/material.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:moliseis/utils/string_validator.dart';
import 'package:provider/provider.dart';

class DetailSources extends StatelessWidget {
  const DetailSources({super.key, required this.texts});

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
          return StringValidator.isValidUrl(e)
              ? UrlTextButton.icon(
                  label: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                  icon: const Icon(Icons.link),
                  iconSize: 18.0,
                  onPressed: () async {
                    if (!await context
                        .read<UrlLaunchService>()
                        .launchGenericUrl(e)) {
                      if (context.mounted) {
                        showSnackBar(
                          context: context,
                          textContent:
                              'Si è verificato un errore, riprova più tardi.',
                        );
                      }
                    }
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
