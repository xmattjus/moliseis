import 'package:flutter/material.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/category/widgets/category_content_wrap.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_description_form_field.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Category, content, and controlled event-date fields shared by submission
/// editors.
class ContentSubmissionFields extends StatelessWidget {
  /// Creates the shared editable content-submission fields.
  const ContentSubmissionFields({
    required this.formKey,
    required this.category,
    required this.city,
    required this.name,
    required this.description,
    required this.descriptionDelta,
    required this.isEvent,
    required this.startCalendarDate,
    required this.startClockTime,
    required this.endCalendarDate,
    required this.eventTimeIssue,
    required this.onCategorySelected,
    required this.onCategoryDeleted,
    required this.onCityChanged,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onEventChanged,
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
  final bool isEvent;
  final EventCalendarDate? startCalendarDate;
  final EventClockTime? startClockTime;
  final EventCalendarDate? endCalendarDate;
  final EventTimeIssue? eventTimeIssue;
  final ValueChanged<ContentCategory> onCategorySelected;
  final VoidCallback onCategoryDeleted;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onNameChanged;
  final void Function({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  })
  onDescriptionChanged;
  final ValueChanged<bool> onEventChanged;
  final ValueChanged<EventCalendarDate> onStartDateChanged;
  final ValueChanged<EventClockTime> onStartTimeChanged;
  final ValueChanged<EventCalendarDate> onEndDateChanged;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.textTheme.bodyLarge;
    final locale = Localizations.localeOf(context);
    final issueText = _eventTimeIssueText(eventTimeIssue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TextSectionDivider(
          'Categoria',
          padding: EdgeInsets.symmetric(vertical: 8),
        ),
        CategoryContentWrap(
          selectedCategory: category,
          onCategoryDeleted: onCategoryDeleted,
          onCategorySelected: onCategorySelected,
        ),
        const TextSectionDivider(
          'Dettagli',
          padding: EdgeInsets.only(top: 16, bottom: 12),
        ),
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: <Widget>[
              TextFormField(
                initialValue: city,
                decoration: const InputDecoration(
                  labelText: 'Città',
                  hintText: 'San Pietro Avellana',
                ),
                onChanged: onCityChanged,
                validator: (value) {
                  if (value?.isEmpty ?? false) {
                    return 'Inserisci il nome di una città';
                  }
                  if ((value?.length ?? 0) > 100) {
                    return 'Il nome della città inserito è troppo lungo';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(
                  labelText: 'Luogo o evento',
                  hintText: 'Museo del Tartufo',
                ),
                onChanged: onNameChanged,
                validator: (value) {
                  if (value?.isEmpty ?? false) {
                    return 'Inserisci il nome di un luogo o di un evento';
                  }
                  if ((value?.length ?? 0) > 150) {
                    return "Il nome del luogo o dell'evento inserito è "
                        'troppo lungo';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              ContentSubmissionDescriptionFormField(
                initialDescription: description,
                initialDescriptionDelta: descriptionDelta,
                onChanged: onDescriptionChanged,
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
              value: isEvent,
              onChanged: (value) => onEventChanged(value ?? false),
            ),
          ],
        ),
        if (isEvent)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ContentSubmissionDateChip.date(
                selectedDate: startCalendarDate,
                label: Text(
                  startCalendarDate == null
                      ? 'Seleziona data di inizio'
                      : 'Inizia il ${_formatDate(startCalendarDate!, locale)}',
                ),
                onDatePicked: onStartDateChanged,
              ),
              if (startCalendarDate != null)
                ContentSubmissionDateChip.time(
                  selectedTime: startClockTime,
                  label: Text(
                    startClockTime == null
                        ? 'Seleziona ora di inizio'
                        : 'Inizia alle ${_formatTime(startClockTime!, locale)}',
                  ),
                  onTimePicked: onStartTimeChanged,
                ),
              ContentSubmissionDateChip.date(
                firstDate: startCalendarDate,
                selectedDate: endCalendarDate ?? startCalendarDate,
                label: Text(
                  endCalendarDate == null
                      ? 'Seleziona data di fine'
                      : 'Finisce il ${_formatDate(endCalendarDate!, locale)}',
                ),
                onDatePicked: onEndDateChanged,
              ),
            ],
          ),
        if (issueText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              issueText,
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        if (isEvent) const SizedBox(height: 8),
      ],
    );
  }

  String _formatDate(EventCalendarDate date, Locale locale) =>
      DateTime(date.year, date.month, date.day).formatDate(locale);

  String _formatTime(EventClockTime time, Locale locale) =>
      DateTime(2000, 1, 1, time.hour, time.minute).formatTime(locale);

  String? _eventTimeIssueText(EventTimeIssue? issue) => switch (issue) {
    EventTimeIssue.nonexistentLocalTime =>
      "L'orario selezionato non esiste in Italia per il cambio dell'ora.",
    EventTimeIssue.ambiguousLocalTime =>
      "L'orario selezionato è ambiguo per il cambio dell'ora.",
    EventTimeIssue.missingStartDate => 'Seleziona una data di inizio.',
    EventTimeIssue.missingStartTime => 'Seleziona un orario di inizio.',
    EventTimeIssue.invalidRange => 'Inserisci un intervallo di date valido.',
    null => null,
  };
}
