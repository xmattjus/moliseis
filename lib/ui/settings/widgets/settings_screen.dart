import 'dart:async' show unawaited;
import 'dart:collection' show UnmodifiableListView;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

// import 'package:moliseis/features/settings/domain/theme_type.dart';

// typedef _ThemeTypeEntry = DropdownMenuEntry<ThemeType>;

typedef _ThemeBrightnessEntry = DropdownMenuEntry<ThemeBrightness>;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  ///
  Widget _buildSectionText(BuildContext context, String s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(s, style: context.appTypography.section),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyles(context).surface,
      child: Scaffold(
        appBar: AppBar(
          leading: CustomBackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouteNames.home);
              }
            },
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
                        onSelected: (brightness) {
                          if (brightness != null) {
                            themeProvider.setThemeBrightness.run(brightness);
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

                return ListenableBuilder(
                  listenable: viewModel.setCrashReporting.isRunningSync,
                  builder: (context, _) => SwitchListTile(
                    value: sentryLoggingEnabled,
                    onChanged: (value) async {
                      final command = viewModel.setCrashReporting;
                      if (viewModel.isDisposed ||
                          command.isRunningSync.value ||
                          !command.canRun.value) {
                        return;
                      }
                      // The global handler reports unexpected failures.
                      // This continuation only observes its own admitted run.
                      final result = await command
                          .runAsync(value)
                          .then(
                            (result) => result,
                            onError: (Object _, StackTrace _) => null,
                          );
                      if (!context.mounted) return;
                      if (viewModel.isDisposed ||
                          !identical(
                            context.read<SettingsViewModel>(),
                            viewModel,
                          )) {
                        return;
                      }
                      if (result case Success<CrashReportingUpdate>(
                        :final value,
                      )) {
                        if (!viewModel.isCurrent(value)) return;
                        final text = switch (value.outcome) {
                          CrashReportingOutcome.enabledForNextStart =>
                            'La segnalazione degli errori sarà attivata '
                                "al prossimo avvio dell'app.",
                          CrashReportingOutcome.disabled =>
                            'La segnalazione di nuovi errori '
                                'è stata disattivata.',
                          CrashReportingOutcome.shutdownUnconfirmed =>
                            'Preferenza salvata; arresto non confermato. '
                                'Vale dal prossimo avvio.',
                          CrashReportingOutcome.superseded => null,
                        };
                        if (text == null) return;
                        showSnackBar(
                          context: context,
                          textContent: text,
                          type:
                              value.outcome ==
                                  CrashReportingOutcome.shutdownUnconfirmed
                              ? SnackBarType.error
                              : SnackBarType.info,
                        );
                      } else if (result == null &&
                          !value &&
                          !viewModel.committedCrashReporting &&
                          viewModel.reportingState ==
                              CrashReportingState.unconfirmed) {
                        // The command already reported the original raw error.
                        showSnackBar(
                          context: context,
                          textContent:
                              'Preferenza salvata; arresto non confermato. '
                              'Vale dal prossimo avvio.',
                          type: SnackBarType.error,
                        );
                      } else if (result is Error<CrashReportingUpdate>) {
                        showSnackBar(
                          context: context,
                          textContent:
                              'Non è stato possibile salvare la preferenza. '
                              'Riprova.',
                          type: SnackBarType.error,
                        );
                      }
                    },
                    title: const Text('Segnalazione errori'),
                    subtitle: Text(
                      viewModel.setCrashReporting.isRunningSync.value
                          ? 'Salvataggio della preferenza e '
                                'aggiornamento della segnalazione…'
                          : switch (viewModel.reportingState) {
                              CrashReportingState.closing =>
                                sentryLoggingEnabled
                                    ? 'Arresto in corso. '
                                          'Attivazione al prossimo avvio.'
                                    : 'Arresto della segnalazione in corso…',
                              CrashReportingState.unconfirmed =>
                                sentryLoggingEnabled
                                    ? 'Arresto non confermato. '
                                          'La segnalazione sarà '
                                          'attivata al prossimo avvio.'
                                    : 'Preferenza salvata. '
                                          'Arresto non confermato; '
                                          'la segnalazione sarà disattivata '
                                          'al prossimo avvio.',
                              CrashReportingState.active =>
                                "Gli errori dell'app verranno inviati "
                                    'automaticamente agli sviluppatori',
                              CrashReportingState.inactive =>
                                sentryLoggingEnabled
                                    ? 'La segnalazione sarà attivata '
                                          'al prossimo avvio.'
                                    : 'La segnalazione di nuovi errori '
                                          'è disattivata.',
                            },
                    ),
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
