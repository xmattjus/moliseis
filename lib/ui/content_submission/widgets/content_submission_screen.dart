import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/category/widgets/category_content_wrap.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_add_asset_form.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

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

  /// Whether the current content submission is an event or not.
  bool _isEvent = false;

  @override
  void initState() {
    super.initState();
    // heuristically restore only if the draft has been loaded by this point;
    // `ContentSubmissionViewModel.initialize()` is awaited `unawaited` from
    // `lib/config/dependencies.dart`, so on a cold start the draft may not
    // be ready yet. The form rebuilds on `notifyListeners` fires from
    // `_loadState → ready`, but `_isEvent` is local `setState`-driven state
    // and is not re-derived afterwards — accept the rare cold-start miss
    // (no dates shown until the user re-toggles the checkbox).
    final draft = widget.viewModel.state;
    _isEvent = draft.startDate != null || draft.endDate != null;
    unawaited(widget.viewModel.retrieveLostAssets.execute());
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
            listenable: widget.viewModel,
            builder: (context, child) {
              if (widget.viewModel.loadState ==
                  ContentSubmissionDraftLoadState.loading) {
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
                        const TextSectionDivider(
                          'Categoria',
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        CategoryContentWrap(
                          selectedCategory: widget.viewModel.state.category,
                          onCategoryDeleted: () =>
                              widget.viewModel.setCategory(null),
                          onCategorySelected: (value) =>
                              widget.viewModel.setCategory(value),
                        ),
                        const TextSectionDivider(
                          'Dettagli',
                          padding: EdgeInsetsDirectional.only(
                            top: 16,
                            bottom: 8,
                          ),
                        ),
                        Form(
                          key: _form1Key,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 12,
                            children: [
                              TextFormField(
                                initialValue: widget.viewModel.state.city,
                                decoration: const InputDecoration(
                                  labelText: 'Città',
                                  hintText: 'San Pietro Avellana',
                                ),
                                onChanged: (value) =>
                                    widget.viewModel.setCity(value),
                                validator: (value) {
                                  if (value != null) {
                                    if (value.isEmpty) {
                                      return 'Inserisci il nome di una città';
                                    } else if (value.length > 100) {
                                      return 'Il nome della città inserito è '
                                          'troppo lungo';
                                    }
                                  }

                                  return null;
                                },
                                autovalidateMode: AutovalidateMode.onUnfocus,
                              ),
                              TextFormField(
                                initialValue: widget.viewModel.state.name,
                                decoration: const InputDecoration(
                                  labelText: 'Luogo o evento',
                                  hintText: 'Museo del Tartufo',
                                ),
                                onChanged: (value) =>
                                    widget.viewModel.setName(value),
                                validator: (value) {
                                  if (value != null) {
                                    if (value.isEmpty) {
                                      return 'Inserisci il nome di un luogo o '
                                          'di un evento.';
                                    } else if (value.length > 150) {
                                      return "Il nome del luogo o dell'evento "
                                          'inserito è troppo lungo';
                                    }
                                  }
                                  return null;
                                },
                                autovalidateMode: AutovalidateMode.onUnfocus,
                              ),
                              TextFormField(
                                initialValue:
                                    widget.viewModel.state.description,
                                decoration: const InputDecoration(
                                  labelText: 'Descrizione',
                                  hintText:
                                      'Raccontaci qualcosa di questo luogo o '
                                      'evento',
                                ),
                                maxLines: 5,
                                minLines: 2,
                                onChanged: (value) =>
                                    widget.viewModel.setDescription(value),
                                validator: (value) {
                                  if (value != null && value.length > 5000) {
                                    return 'La descrizione inserita è troppo '
                                        ' lunga';
                                  }
                                  return null;
                                },
                                autovalidateMode: AutovalidateMode.onUnfocus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 16,
                          children: [
                            Text('È un evento?', style: textStyle),
                            Checkbox(
                              value: _isEvent,
                              onChanged: (value) => setState(() {
                                _isEvent = value ?? !_isEvent;
                              }),
                            ),
                          ],
                        ),
                        if (_isEvent)
                          Builder(
                            builder: (context) {
                              final startDate =
                                  widget.viewModel.state.startDate;

                              final endDate = widget.viewModel.state.endDate;

                              final currentLocale = Localizations.localeOf(
                                context,
                              );

                              return Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ContentSubmissionDateChip(
                                    initialDate: startDate,
                                    label: Text(
                                      startDate != null
                                          ? 'Inizia il ${startDate.formatDate(
                                              currentLocale,
                                            )}'
                                          : 'Seleziona data di inizio',
                                    ),
                                    onDatePicked: (date) {
                                      widget.viewModel.setStartDate(date);
                                    },
                                  ),
                                  if (startDate != null)
                                    ContentSubmissionDateChip(
                                      initialDate: startDate,
                                      label: Text(
                                        'Inizia alle ${startDate.formatTime(
                                          currentLocale,
                                        )}',
                                      ),
                                      mode: ContentSubmissionDateChipMode.time,
                                      onDatePicked: (date) {
                                        widget.viewModel.setStartTime(date);
                                      },
                                    ),
                                  ContentSubmissionDateChip(
                                    firstDate: startDate,
                                    initialDate: endDate ?? startDate,
                                    label: Text(
                                      endDate != null
                                          ? 'Finisce il ${endDate.formatDate(
                                              currentLocale,
                                            )}'
                                          : 'Seleziona data di fine',
                                    ),
                                    onDatePicked: (date) {
                                      widget.viewModel.setEndDate(date);
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        if (_isEvent) const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverList.list(
                    children: [
                      ContentSubmissionAddAssetForm(
                        viewModel: widget.viewModel,
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            Text(
                              'Il servizio è completamente gratuito.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Il luogo o l'evento da te segnalato verrà "
                              'pubblicato sulla piattaforma il prima '
                              'possibile.',
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
                              TextFormField(
                                autovalidateMode: AutovalidateMode.onUnfocus,
                                initialValue: widget.viewModel.state.userEmail,
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
                              const SizedBox(height: 12),
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
                                      return 'Il nome inserito è troppo lungo.';
                                    }
                                  }
                                  return null;
                                },
                                autovalidateMode: AutovalidateMode.onUnfocus,
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
                                              onTap: () => context
                                                  .read<UrlLaunchService>()
                                                  .openTermsOfService(),
                                              child: Text(
                                                'Termini di Servizio',
                                                style: linkTextStyle,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const WidgetSpan(child: Text(" e l'")),
                                        WidgetSpan(
                                          child: Semantics(
                                            label: 'Informativa sulla privacy',
                                            excludeSemantics: true,
                                            child: InkWell(
                                              onTap: () => context
                                                  .read<UrlLaunchService>()
                                                  .openPrivacyPolicy(),
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
                      OutlinedButton.icon(
                        onPressed: () async {
                          // The form keys are only attached once the form
                          // widgets have been built. Guard against the null
                          // case rather than forcing an unwrap, which would
                          // crash if the button were ever enabled before the
                          // forms were mounted.
                          final form1State = _form1Key.currentState;
                          final form2State = _form2Key.currentState;
                          final isForm1Valid = form1State?.validate() ?? false;
                          final isForm2Valid = form2State?.validate() ?? false;

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
