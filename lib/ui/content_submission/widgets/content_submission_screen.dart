import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Main content submission form screen.
///
/// Composes shared fields, an asset list, and author/contact details into a
/// scrollable form driven by [ContentSubmissionViewModel]. Handles draft
/// restoration, validation, and submission flow including navigation to the
/// progress screen.
class ContentSubmissionScreen extends StatefulWidget {
  const ContentSubmissionScreen({required this.viewModel, super.key});

  final ContentSubmissionViewModel viewModel;

  @override
  State<ContentSubmissionScreen> createState() =>
      _ContentSubmissionScreenState();
}

class _ContentSubmissionScreenState extends State<ContentSubmissionScreen> {
  final _form1Key = GlobalKey<FormState>();
  final _form2Key = GlobalKey<FormState>();
  var _clearEpoch = 0;

  @override
  void initState() {
    super.initState();
    widget.viewModel.clear.addListener(_handleClearCompleted);
    unawaited(widget.viewModel.retrieveLostAssets.execute());
  }

  @override
  void dispose() {
    widget.viewModel.clear.removeListener(_handleClearCompleted);
    super.dispose();
  }

  /// Rebuilds the shared form with cleared state after a successful clear.
  ///
  /// While the clear command runs, the form is replaced by a loading state so
  /// stale submitted values cannot be edited. Incrementing [_clearEpoch]
  /// replaces the shared form, including its local event-flag state, before a
  /// post-frame `FormState.reset()` reapplies the cleared values.
  void _handleClearCompleted() {
    if (!mounted || !widget.viewModel.clear.completed) return;
    setState(() => _clearEpoch++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _form1Key.currentState?.reset();
      _form2Key.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final textStyle = textTheme.bodyLarge;

    final linkTextStyle = AppTextStyles.link(
      context,
    )?.copyWith(fontSize: textTheme.bodyMedium?.fontSize);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.colorScheme.surface,
        systemNavigationBarDividerColor: context.colorScheme.surface,
        systemNavigationBarIconBrightness: context.isDarkTheme
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              widget.viewModel,
              widget.viewModel.clear,
            ]),
            builder: (context, child) {
              if (widget.viewModel.loadState ==
                      ContentSubmissionDraftLoadState.loading ||
                  widget.viewModel.clear.running) {
                return const EmptyView.loading(
                  text: Text('Caricamento in corso...'),
                );
              }

              return CustomScrollView(
                key: const ValueKey('content_submission_scroll'),
                slivers: <Widget>[
                  const SliverAppBar(title: Text('Suggerimento')),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.list(
                      children: [
                        ContentSubmissionFields(
                          key: ValueKey(_clearEpoch),
                          formKey: _form1Key,
                          category: widget.viewModel.state.category,
                          city: widget.viewModel.state.city,
                          name: widget.viewModel.state.name,
                          description: widget.viewModel.state.description,
                          descriptionDelta:
                              widget.viewModel.state.descriptionDelta,
                          startDate: widget.viewModel.state.startDate,
                          endDate: widget.viewModel.state.endDate,
                          onCategorySelected: widget.viewModel.setCategory,
                          onCategoryDeleted: () =>
                              widget.viewModel.setCategory(null),
                          onCityChanged: widget.viewModel.setCity,
                          onNameChanged: widget.viewModel.setName,
                          onDescriptionChanged: widget.viewModel.setDescription,
                          onStartDateChanged: widget.viewModel.setStartDate,
                          onStartTimeChanged: widget.viewModel.setStartTime,
                          onEndDateChanged: widget.viewModel.setEndDate,
                        ),
                      ],
                    ),
                  ),
                  SliverList.list(
                    children: [
                      ContentSubmissionAssetList(
                        viewModel: widget.viewModel,
                      ),
                      const SizedBox(height: 32),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            Text(
                              'Il servizio è completamente gratuito',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Il luogo o l'evento da te segnalato verrà "
                              'pubblicato sulla piattaforma il prima '
                              'possibile',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Form(
                          key: _form2Key,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SentryMask(
                                TextFormField(
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  initialValue:
                                      widget.viewModel.state.userEmail,
                                  decoration: const InputDecoration(
                                    labelText: 'E-mail',
                                    hintText: 'mario.rossi@gmail.com',
                                  ),
                                  onChanged: (value) =>
                                      widget.viewModel.setUserEmail(value),
                                  validator: (value) {
                                    if (value != null) {
                                      if (!widget.viewModel.validateEmail(
                                        value,
                                      )) {
                                        return 'Inserisci un indirizzo e-mail '
                                            'valido';
                                      } else if (value.length > 320) {
                                        return "L'indirizzo e-mail inserito è "
                                            'troppo lungo';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              SentryMask(
                                TextFormField(
                                  initialValue: widget.viewModel.state.userName,
                                  decoration: const InputDecoration(
                                    labelText: 'Autore',
                                    hintText: 'Mario Rossi',
                                  ),
                                  onChanged: (value) =>
                                      widget.viewModel.setUserName(value),
                                  validator: (value) {
                                    if (value != null) {
                                      if (value.isEmpty) {
                                        return 'Inserisci il tuo nome';
                                      } else if (value.length > 100) {
                                        return 'Il nome inserito è troppo '
                                            'lungo.';
                                      }
                                    }
                                    return null;
                                  },
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                ),
                              ),
                              const SizedBox(height: 16),
                              CheckboxFormField(
                                initialValue:
                                    widget.viewModel.state.acceptedTerms ??
                                    false,
                                onChanged: (value) =>
                                    widget.viewModel.setAcceptedTerms(value),
                                title: MergeSemantics(
                                  child: RichText(
                                    text: TextSpan(
                                      style: textStyle,
                                      children: [
                                        const WidgetSpan(
                                          child: Text(
                                            'Inviando il suggerimento, accetti '
                                            'i ',
                                          ),
                                        ),
                                        WidgetSpan(
                                          child: Semantics(
                                            label: 'Termini di Servizio',
                                            excludeSemantics: true,
                                            child: InkWell(
                                              onTap: () async {
                                                final launched = await context
                                                    .read<UrlLaunchService>()
                                                    .openTermsOfService();
                                                if (context.mounted &&
                                                    !launched) {
                                                  showSnackBarGenericError(
                                                    context: context,
                                                  );
                                                }
                                              },
                                              child: Text(
                                                'Termini di Servizio',
                                                style: linkTextStyle,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const WidgetSpan(
                                          child: Text(" e l'"),
                                        ),
                                        WidgetSpan(
                                          child: Semantics(
                                            label: 'Informativa sulla privacy',
                                            excludeSemantics: true,
                                            child: InkWell(
                                              onTap: () async {
                                                final launched = await context
                                                    .read<UrlLaunchService>()
                                                    .openPrivacyPolicy();
                                                if (context.mounted &&
                                                    !launched) {
                                                  showSnackBarGenericError(
                                                    context: context,
                                                  );
                                                }
                                              },
                                              child: Text(
                                                'Informativa sulla privacy',
                                                style: linkTextStyle,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const WidgetSpan(
                                          child: Text(' di Molise Is'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value != true) {
                                    return 'Devi accettare i Termini di '
                                        "Servizio e l'Informativa sulla "
                                        'privacy.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 16,
                          ),
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              // The form keys are only attached once the form
                              // widgets have been built. Guard against the null
                              // case rather than forcing an unwrap, which would
                              // crash if the button were ever enabled before
                              // the forms were mounted.
                              final form1State = _form1Key.currentState;
                              final form2State = _form2Key.currentState;
                              final isForm1Valid =
                                  form1State?.validate() ?? false;
                              final isForm2Valid =
                                  form2State?.validate() ?? false;

                              if (isForm1Valid && isForm2Valid) {
                                unawaited(widget.viewModel.submit.execute());
                                unawaited(
                                  context.pushNamed(
                                    RouteNames.contentSubmissionUploadProgress,
                                  ),
                                );
                              }
                            },
                            label: const Text('Invia'),
                            icon: const Icon(Symbols.upload),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
