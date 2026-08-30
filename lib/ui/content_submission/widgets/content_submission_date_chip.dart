import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// A semantic date or time picker chip for content submission editors.
///
/// The picker-only [DateTime] carriers never cross this widget boundary:
/// [ContentSubmissionDateChip.date] exchanges calendar days, while
/// [ContentSubmissionDateChip.time] exchanges clock times.
class ContentSubmissionDateChip extends StatefulWidget {
  /// Creates a chip that selects an event calendar day.
  const ContentSubmissionDateChip.date({
    super.key,
    this.firstDate,
    this.selectedDate,
    required this.label,
    this.leading,
    required this.onDatePicked,
    this.nowUtc,
  }) : _mode = _ContentSubmissionDateChipMode.date,
       onTimePicked = null,
       selectedTime = null;

  /// Creates a chip that selects an event clock time.
  const ContentSubmissionDateChip.time({
    super.key,
    this.selectedTime,
    required this.label,
    this.leading,
    required this.onTimePicked,
    this.nowUtc,
  }) : _mode = _ContentSubmissionDateChipMode.time,
       onDatePicked = null,
       firstDate = null,
       selectedDate = null;

  /// Lower selectable date bound, when this is a date chip.
  final EventCalendarDate? firstDate;

  /// Selected calendar day, when this is a date chip.
  final EventCalendarDate? selectedDate;

  /// Selected clock time, when this is a time chip.
  final EventClockTime? selectedTime;

  /// Testable UTC source for Rome-based picker defaults.
  final DateTime? nowUtc;

  /// Label rendered inside the chip.
  final Widget label;

  /// Optional leading widget shown before [label].
  final Widget? leading;

  final _ContentSubmissionDateChipMode _mode;
  final ValueChanged<EventCalendarDate>? onDatePicked;
  final ValueChanged<EventClockTime>? onTimePicked;

  @override
  State<ContentSubmissionDateChip> createState() =>
      _ContentSubmissionDateChipState();
}

enum _ContentSubmissionDateChipMode { date, time }

class _ContentSubmissionDateChipState extends State<ContentSubmissionDateChip> {
  final _eventTimePolicy = EventTimePolicy();
  DateTime? _selectedDateTime;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: widget.leading,
      label: widget.label,
      onPressed: _openPicker,
    );
  }

  DateTime get _nowUtc => (widget.nowUtc ?? DateTime.now()).toUtc();

  DateTime _dateCarrier(EventCalendarDate date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _timeCarrier(EventClockTime time) =>
      DateTime(2000, 1, 1, time.hour, time.minute);

  EventCalendarDate get _defaultDate =>
      _eventTimePolicy.currentCalendarDate(_nowUtc);

  EventClockTime get _defaultTime {
    final now = _eventTimePolicy.currentClockTime(_nowUtc);
    return EventClockTime(now.hour, now.minute - (now.minute % 5));
  }

  Future<void> _openPicker() async {
    final selectedDate = widget.selectedDate ?? _defaultDate;
    final selectedTime = widget.selectedTime ?? _defaultTime;
    final requestedFirstDate =
        widget.firstDate ?? EventCalendarDate(selectedDate.year, 1, 1);
    final effectiveInitialDate =
        _dateCarrier(selectedDate).isBefore(
          _dateCarrier(requestedFirstDate),
        )
        ? requestedFirstDate
        : selectedDate;
    final lastDate = EventCalendarDate(effectiveInitialDate.year, 12, 31);
    final initial = widget._mode == _ContentSubmissionDateChipMode.date
        ? _dateCarrier(effectiveInitialDate)
        : _timeCarrier(selectedTime);

    if (defaultTargetPlatform == TargetPlatform.iOS &&
        context.windowSizeClass.isCompact) {
      _selectedDateTime = initial;
      await _showCupertinoPicker(
        initial: initial,
        firstDate: widget._mode == _ContentSubmissionDateChipMode.date
            ? _dateCarrier(requestedFirstDate)
            : null,
        lastDate: widget._mode == _ContentSubmissionDateChipMode.date
            ? _dateCarrier(lastDate)
            : null,
      );
      return;
    }

    await _showMaterialPicker(
      initial: initial,
      firstDate: _dateCarrier(requestedFirstDate),
      lastDate: _dateCarrier(lastDate),
    );
  }

  Future<void> _showCupertinoPicker({
    required DateTime initial,
    required DateTime? firstDate,
    required DateTime? lastDate,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (dialogContext) {
        if (!mounted) return const SizedBox.shrink();
        return Container(
          constraints: const BoxConstraints.expand(height: 216),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(dialogContext),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                CupertinoTheme(
                  data: const CupertinoThemeData(
                    primaryColor: CupertinoColors.activeBlue,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        sizeStyle: CupertinoButtonSize.medium,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Annulla'),
                      ),
                      Expanded(
                        child: Text(
                          widget._mode == _ContentSubmissionDateChipMode.date
                              ? 'Seleziona una data'
                              : "Seleziona un'ora",
                          style: Theme.of(dialogContext).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'system',
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      CupertinoButton(
                        sizeStyle: CupertinoButtonSize.medium,
                        onPressed: () {
                          final value = _selectedDateTime;
                          if (value != null) _emit(value);
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Conferma'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: widget._mode == _ContentSubmissionDateChipMode.date
                        ? CupertinoDatePickerMode.date
                        : CupertinoDatePickerMode.time,
                    initialDateTime: initial,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    minuteInterval: 5,
                    use24hFormat: true,
                    dateOrder: DatePickerDateOrder.dmy,
                    onDateTimeChanged: (value) => _selectedDateTime = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMaterialPicker({
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    switch (widget._mode) {
      case _ContentSubmissionDateChipMode.date:
        final selected = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (!mounted || selected == null) return;
        _emit(selected);
      case _ContentSubmissionDateChipMode.time:
        final selected = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initial),
        );
        if (!mounted || selected == null) return;
        _emit(DateTime(2000, 1, 1, selected.hour, selected.minute));
    }
  }

  void _emit(DateTime value) {
    if (!mounted) return;
    switch (widget._mode) {
      case _ContentSubmissionDateChipMode.date:
        widget.onDatePicked!(
          EventCalendarDate(value.year, value.month, value.day),
        );
      case _ContentSubmissionDateChipMode.time:
        widget.onTimePicked!(EventClockTime(value.hour, value.minute));
    }
  }
}
