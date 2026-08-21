import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/category/widgets/category_content_wrap.dart';
import 'package:moliseis/ui/content_submission/widgets/content_description_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Category, city/name/description fields, event flag, and date chips shared
/// by the public submission form and the admin submission editor.
///
/// Receives state values and callbacks only; it never depends on a specific
/// ViewModel.
class ContentSubmissionFields extends StatefulWidget {
  /// Creates the shared editable content-submission fields.
  const ContentSubmissionFields({
    required this.formKey,
    required this.category,
    required this.city,
    required this.name,
    required this.description,
    required this.descriptionDelta,
    required this.startDate,
    required this.endDate,
    required this.onCategorySelected,
    required this.onCategoryDeleted,
    required this.onCityChanged,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onStartDateChanged,
    required this.onStartTimeChanged,
    required this.onEndDateChanged,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final ContentCategory? category;
  final String? city;
  final String? name;
  final String? description;
  final List<Map<String, dynamic>>? descriptionDelta;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<ContentCategory> onCategorySelected;
  final VoidCallback onCategoryDeleted;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onNameChanged;
  final void Function({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  })
  onDescriptionChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onStartTimeChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  @override
  State<ContentSubmissionFields> createState() =>
      _ContentSubmissionFieldsState();
}

class _ContentSubmissionFieldsState extends State<ContentSubmissionFields> {
  var _isEvent = false;

  @override
  void initState() {
    super.initState();
    // Heuristically restores event state from the values supplied at creation.
    // The public draft can load after this widget's first build, but the event
    // state is local and not re-derived after that update; accept the rare
    // cold-start miss until the user re-toggles the checkbox.
    _isEvent = widget.startDate != null || widget.endDate != null;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = context.textTheme.bodyLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TextSectionDivider(
          'Categoria',
          padding: EdgeInsets.symmetric(vertical: 8),
        ),
        CategoryContentWrap(
          selectedCategory: widget.category,
          onCategoryDeleted: widget.onCategoryDeleted,
          onCategorySelected: widget.onCategorySelected,
        ),
        const TextSectionDivider(
          'Dettagli',
          padding: EdgeInsets.only(top: 16, bottom: 12),
        ),
        Form(
          key: widget.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: <Widget>[
              TextFormField(
                initialValue: widget.city,
                decoration: const InputDecoration(
                  labelText: 'Città',
                  hintText: 'San Pietro Avellana',
                ),
                onChanged: widget.onCityChanged,
                validator: (value) {
                  if (value != null) {
                    if (value.isEmpty) {
                      return 'Inserisci il nome di una città';
                    } else if (value.length > 100) {
                      return 'Il nome della città inserito è troppo lungo';
                    }
                  }

                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              TextFormField(
                initialValue: widget.name,
                decoration: const InputDecoration(
                  labelText: 'Luogo o evento',
                  hintText: 'Museo del Tartufo',
                ),
                onChanged: widget.onNameChanged,
                validator: (value) {
                  if (value != null) {
                    if (value.isEmpty) {
                      return 'Inserisci il nome di un luogo o di un evento';
                    } else if (value.length > 150) {
                      return "Il nome del luogo o dell'evento inserito è "
                          'troppo lungo';
                    }
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              ContentDescriptionFormField(
                initialDescription: widget.description,
                initialDescriptionDelta: widget.descriptionDelta,
                onChanged: widget.onDescriptionChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 16,
          children: <Widget>[
            Text('È un evento?', style: textStyle),
            Checkbox(
              value: _isEvent,
              onChanged: (value) {
                if (value == true) {
                  setState(() => _isEvent = true);
                  return;
                }

                // Turning an event into a place must clear persisted dates so
                // the submission cannot retain an invisible event state.
                widget.onStartDateChanged(null);
                widget.onEndDateChanged(null);
                setState(() => _isEvent = false);
              },
            ),
          ],
        ),
        if (_isEvent)
          Builder(
            builder: (context) {
              final startDate = widget.startDate;
              final endDate = widget.endDate;
              final currentLocale = Localizations.localeOf(context);

              return Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ContentSubmissionDateChip(
                    initialDate: startDate,
                    label: Text(
                      startDate != null
                          ? 'Inizia il ${startDate.formatDate(currentLocale)}'
                          : 'Seleziona data di inizio',
                    ),
                    onDatePicked: widget.onStartDateChanged,
                  ),
                  if (startDate != null)
                    ContentSubmissionDateChip(
                      initialDate: startDate,
                      label: Text(
                        'Inizia alle ${startDate.formatTime(currentLocale)}',
                      ),
                      mode: ContentSubmissionDateChipMode.time,
                      onDatePicked: widget.onStartTimeChanged,
                    ),
                  ContentSubmissionDateChip(
                    firstDate: startDate,
                    initialDate: endDate ?? startDate,
                    label: Text(
                      endDate != null
                          ? 'Finisce il ${endDate.formatDate(currentLocale)}'
                          : 'Seleziona data di fine',
                    ),
                    onDatePicked: widget.onEndDateChanged,
                  ),
                ],
              );
            },
          ),
        if (_isEvent) const SizedBox(height: 8),
      ],
    );
  }
}
