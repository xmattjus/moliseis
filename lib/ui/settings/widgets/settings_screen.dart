import 'dart:async' show unawaited;
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
// import 'package:moliseis/features/settings/domain/theme_type.dart';
import 'package:provider/provider.dart';

// typedef _ThemeTypeEntry = DropdownMenuEntry<ThemeType>;

typedef _ThemeBrightnessEntry = DropdownMenuEntry<ThemeBrightness>;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  ///
  Widget _buildSectionText(BuildContext context, String s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(s, style: AppTextStyles.section(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyles(context).surface,
      child: Scaffold(
        appBar: AppBar(
          leading: const CustomBackButton(),
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
                        onSelected: (brightness) async {
                          if (brightness != null) {
                            await themeProvider.setThemeBrightness.execute(
                              brightness,
                            );
                          }
                        },
                        dropdownMenuEntries:
                            UnmodifiableListView<_ThemeBrightnessEntry>(
                              ThemeBrightness.values.map<_ThemeBrightnessEntry>(
                                (listItem) => _ThemeBrightnessEntry(
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
            const SizedBox(height: 16),
            _buildSectionText(context, 'Altro'),
            Consumer<SettingsViewModel>(
              builder: (_, viewModel, _) {
                final sentryLoggingEnabled = viewModel.crashReporting;

                return SwitchListTile(
                  value: sentryLoggingEnabled,
                  onChanged: (value) async {
                    await viewModel.setCrashReporting.execute(value);

                    if (context.mounted && value) {
                      showSnackBar(
                        context: context,
                        textContent:
                            'Gli errori verranno inviati al prossimo avvio '
                            "dell'app",
                      );
                    }
                  },
                  title: const Text('Segnalazione errori'),
                  subtitle: Text(
                    sentryLoggingEnabled
                        ? "Gli errori dell'app verranno inviati "
                              'automaticamente agli sviluppatori'
                        : "Gli errori dell'app non verranno inviati agli "
                              'sviluppatori',
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Area redazione'),
              subtitle: const Text(
                'Rivedi e cura i contributi della community',
              ),
              onTap: () {
                final isAdmin = context.read<AdminAuthViewModel>().isAdmin;
                unawaited(
                  context.push(
                    isAdmin ? RoutePaths.admin : RoutePaths.adminLoginLocation,
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Riguardo Molise Is'),
              onTap: () async {
                await showDialog<void>(
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
                            await Future<void>.delayed(Durations.short3);
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
              title: const Text('Termini di Servizio'),
              onTap: () async {
                final launched = await context
                    .read<UrlLaunchService>()
                    .openTermsOfService();
                if (context.mounted && !launched) {
                  showSnackBarGenericError(context: context);
                }
              },
            ),
            ListTile(
              title: const Text('Informativa sulla privacy'),
              onTap: () async {
                final launched = await context
                    .read<UrlLaunchService>()
                    .openPrivacyPolicy();
                if (context.mounted && !launched) {
                  showSnackBarGenericError(context: context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
