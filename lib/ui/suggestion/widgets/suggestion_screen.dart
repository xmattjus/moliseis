import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/suggestion/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/suggestion/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/suggestion/widgets/suggestion_date_chip.dart';
import 'package:moliseis/ui/suggestion/widgets/suggestion_image_gallery.dart';
import 'package:moliseis/ui/suggestion/widgets/suggestion_send_button.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';

typedef _TypeMenuEntry = DropdownMenuEntry<AttractionType>;

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key, required this.viewModel});

  final SuggestionViewModel viewModel;

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final _form1Key = GlobalKey<FormState>();
  final _form2Key = GlobalKey<FormState>();

  /// Whether the current suggestion is an event or not.
  bool _isEvent = false;

  @override
  Widget build(BuildContext context) {
    final attractionTypes = widget.viewModel.types;

    final textStyle = Theme.of(context).textTheme.bodyLarge;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(title: Text('Suggerimento')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList.list(
                children: [
                  const SizedBox(height: 8.0),
                  Text('Categoria', style: CustomTextStyles.section(context)),
                  const SizedBox(height: 8.0),
                  DropdownMenu<AttractionType>(
                    initialSelection: attractionTypes.first,
                    dropdownMenuEntries: UnmodifiableListView<_TypeMenuEntry>(
                      attractionTypes.map<_TypeMenuEntry>(
                        (AttractionType type) => DropdownMenuEntry(
                          value: type,
                          label: type == AttractionType.unknown
                              ? '-'
                              : type.label,
                        ),
                      ),
                    ),
                    onSelected: (value) => widget.viewModel.type = value,
                  ),
                  const SizedBox(height: 16.0),
                  Text('Dettagli', style: CustomTextStyles.section(context)),
                  const SizedBox(height: 8.0),
                  Form(
                    key: _form1Key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12.0,
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Città',
                            hintText: 'San Pietro Avellana',
                          ),
                          onChanged: (value) => widget.viewModel.city = value,
                          validator: (value) {
                            if (value != null && value.isEmpty) {
                              return 'Inserisci il nome di una città';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUnfocus,
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Attrazione o evento',
                            hintText: 'Museo del Tartufo',
                          ),
                          onChanged: (value) => widget.viewModel.place = value,
                          validator: (value) {
                            if (value != null && value.isEmpty) {
                              return "Inserisci il nome di un'attrazione o evento.";
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUnfocus,
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Descrizione',
                            hintText:
                                'Raccontaci qualcosa di questo luogo o evento',
                          ),
                          maxLines: 5,
                          minLines: 2,
                          onChanged: (value) =>
                              widget.viewModel.description = value,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    ListenableBuilder(
                      listenable: widget.viewModel,
                      builder: (context, child) {
                        final startDate = widget.viewModel.startDate;

                        final endDate = widget.viewModel.endDate;

                        return Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8.0,
                          children: [
                            SuggestionDateChip(
                              initialDate: startDate,
                              label: Text(
                                startDate != null
                                    ? 'Inizia il ${widget.viewModel.formatDate(startDate)}'
                                    : 'Seleziona data di inizio',
                              ),
                              onDatePicked: (date) {
                                widget.viewModel.setStartDate(date);
                              },
                            ),
                            SuggestionDateChip(
                              firstDate: startDate,
                              initialDate: endDate ?? startDate,
                              label: Text(
                                endDate != null
                                    ? 'Finisce il ${widget.viewModel.formatDate(endDate)}'
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
                  if (_isEvent) const SizedBox(height: 8.0),
                ],
              ),
            ),
            SliverList.list(
              children: [
                SuggestionImageGallery(viewModel: widget.viewModel),
                const SizedBox(height: 16.0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8.0,
                    children: [
                      Text(
                        "Il servizio è completamente gratuito.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Il luogo o l'evento da te segnalato verrà "
                        'pubblicato sulla piattaforma il prima possibile.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Form(
                    key: _form2Key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUnfocus,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'mario.rossi@gmail.com',
                          ),
                          onChanged: (value) =>
                              widget.viewModel.authorEmail = value,
                          validator: (value) {
                            if (!widget.viewModel.validateEmail(value)) {
                              return 'Inserisci un indirizzo e-mail valido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12.0),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Autore',
                            hintText: 'Mario Rossi',
                          ),
                          onChanged: (value) =>
                              widget.viewModel.authorName = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci un nome';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUnfocus,
                        ),
                        const SizedBox(height: 16.0),
                        CheckboxFormField(
                          title: RichText(
                            text: TextSpan(
                              style: textStyle,
                              children: [
                                const TextSpan(
                                  text: 'Inviando il suggerimento, accetti i ',
                                ),
                                TextSpan(
                                  text: 'Termini di Servizio',
                                  style: textStyle?.copyWith(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blue,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      final urlLauncher = context
                                          .read<AppUrlLauncher>();
                                      await urlLauncher.termsOfService();
                                    },
                                ),
                                const TextSpan(text: " e l'"),
                                TextSpan(
                                  text: 'Informativa sulla privacy',
                                  style: textStyle?.copyWith(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blue,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      final urlLauncher = context
                                          .read<AppUrlLauncher>();
                                      await urlLauncher.privacyPolicy();
                                    },
                                ),
                                const TextSpan(text: " di Molise Is"),
                              ],
                            ),
                          ),
                          validator: (value) {
                            if (value != null && !value) {
                              return "Devi accettare i Termini di Servizio e "
                                  "l'Informativa sulla privacy.";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SuggestionSendButton(
                  onPressed: () {
                    final isForm1Valid = _form1Key.currentState!.validate();
                    final isForm2Valid = _form2Key.currentState!.validate();

                    if (isForm1Valid && isForm2Valid) {
                      widget.viewModel.uploadSuggestion.execute();
                    }
                  },
                  viewModel: widget.viewModel,
                ),
              ],
            ),
            const SliverPadding(padding: EdgeInsets.symmetric(vertical: 16.0)),
          ],
        ),
      ),
    );
  }
}
