import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/settings/theme_brightness.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/theme_extensions.dart';
// import 'package:moliseis/features/settings/domain/theme_type.dart';
import 'package:provider/provider.dart';

// typedef _ThemeTypeEntry = DropdownMenuEntry<ThemeType>;

typedef _ThemeBrightnessEntry = DropdownMenuEntry<ThemeBrightness>;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  ///
  Widget _buildSectionText(BuildContext context, String s) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(s, style: CustomTextStyles.section(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => GoRouter.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).canvasColor,
          ),
          icon: ButtonTheme(child: const Icon(Icons.arrow_back)),
        ),
        title: const Text('Impostazioni'),
        forceMaterialTransparency: true,
      ),
      body: ListView(
        children: <Widget>[
          _buildSectionText(context, 'Aspetto'),
          Consumer<ThemeViewModel>(
            builder: (context, themeProvider, child) {
              final darkModeSubtitle = switch (themeProvider.themeMode) {
                ThemeMode.system =>
                  'Verrà attivato automaticamente dal sistema',
                ThemeMode.light => 'Non verrà mai attivato automaticamente',
                ThemeMode.dark => 'Non verrà mai disattivato automaticamente',
              };

              return Column(
                children: <Widget>[
                  /*
          ListTile(
            title: const Text(
                'Colori'
            ),
            trailing: DropdownMenu<ThemeType>(
              initialSelection: themeProvider.themeType,
              onSelected: (ThemeType? type) {
                if (type != null) {
                  themeProvider.setThemeType(type);
                }
              },
              dropdownMenuEntries: UnmodifiableListView<_ThemeTypeEntry>(
                ThemeType.values.map<_ThemeTypeEntry>(
                      (ThemeType listItem) => _ThemeTypeEntry(
                    value: listItem,
                    label: listItem.readableName,
                  ),
                ),
              ),
            ),
          ),

           */
                  ListTile(
                    title: const Text('Tema scuro'),
                    subtitle: Text(darkModeSubtitle),
                    trailing: DropdownMenu<ThemeBrightness>(
                      initialSelection: themeProvider.themeBrightness,
                      onSelected: (ThemeBrightness? brightness) {
                        if (brightness != null) {
                          themeProvider.setThemeBrightness(brightness);
                        }
                      },
                      dropdownMenuEntries:
                          UnmodifiableListView<_ThemeBrightnessEntry>(
                            ThemeBrightness.values.map<_ThemeBrightnessEntry>(
                              (ThemeBrightness listItem) =>
                                  _ThemeBrightnessEntry(
                                    value: listItem,
                                    label: listItem.readableName,
                                  ),
                            ),
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16.0),
          _buildSectionText(context, 'Altro'),
          Consumer<SettingsViewModel>(
            builder: (_, controller, _) {
              /// Whether to log app Exceptions to the Sentry service or
              /// not.
              final reportCrashes = controller.crashReporting;

              return SwitchListTile(
                value: reportCrashes,
                onChanged: (value) {
                  controller.saveCrashReporting(value);

                  if (value == true) {
                    showSnackBar(
                      context: context,
                      textContent:
                          'Gli errori verranno inviati al prossimo avvio '
                          "dell'app.",
                    );
                  }
                },
                title: const Text('Segnalazione errori'),
                subtitle: Text(
                  reportCrashes == true
                      ? "Gli errori dell'app verranno inviati "
                            'automaticamente agli sviluppatori'
                      : "Gli errori dell'app non verranno inviati agli "
                            'sviluppatori',
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Riguardo Molise Is'),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Molise Is'),
                    content: const Text(
                      'La guida perfetta per scoprire le bellezze del '
                      'Molise in modo facile e veloce',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Future.delayed(Durations.short3);
                          if (context.mounted) {
                            showLicensePage(context: context);
                          }
                        },
                        child: const Text('Mostra licenze'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Ok'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text('Informativa sulla privacy'),
            onTap: () async {
              const url =
                  'https://sites.google.com/view/molise-is-privacy-policy/home-page';
              if (!await context.read<AppUrlLauncher>().generic(url)) {
                if (context.mounted) {
                  showSnackBar(
                    context: context,
                    textContent:
                        'Si è verificato un errore, riprova più tardi.',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
