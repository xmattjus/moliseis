import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Different display modes of [SuggestionDateChip].
enum SuggestionDateChipMode { date, time }

class SuggestionDateChip extends StatefulWidget {
  const SuggestionDateChip({
    super.key,
    this.firstDate,
    this.initialDate,
    required this.label,
    this.leading,
    this.mode = SuggestionDateChipMode.date,
    required this.onDatePicked,
  });

  final DateTime? firstDate;
  final DateTime? initialDate;
  final Widget label;
  final Widget? leading;
  final SuggestionDateChipMode mode;
  final void Function(DateTime? date) onDatePicked;

  @override
  State<SuggestionDateChip> createState() => _SuggestionDateChipState();
}

class _SuggestionDateChipState extends State<SuggestionDateChip> {
  DateTime? _selectedDateTime;

  @override
  Widget build(BuildContext context) {
    // The lower and upper bounds of selectable dates.
    const durationLimit = Duration(days: 365 * 3);

    final now = DateTime.now();

    return InputChip(
      avatar: widget.leading,
      label: widget.label,
      onPressed: () async {
        if (Platform.isIOS) {
          if (context.windowSizeClass.isCompact) {
            return _showDialog(
              context,
              Column(
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
                          child: const Text('Annulla'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Text(
                            widget.mode == SuggestionDateChipMode.date
                                ? 'Seleziona una data'
                                : "Seleziona un'ora",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'system',
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        CupertinoButton(
                          sizeStyle: CupertinoButtonSize.medium,
                          child: const Text('Conferma'),
                          onPressed: () {
                            if (_selectedDateTime != null) {
                              widget.onDatePicked(_selectedDateTime);
                            }
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: CupertinoDatePicker(
                      mode: widget.mode == SuggestionDateChipMode.date
                          ? CupertinoDatePickerMode.date
                          : CupertinoDatePickerMode.time,
                      onDateTimeChanged: (value) => _selectedDateTime = value,
                      initialDateTime:
                          widget.initialDate ??
                          now.copyWith(minute: now.minute % 5 * 5),
                      minimumDate:
                          widget.firstDate ?? now.subtract(durationLimit),
                      maximumDate: now.add(durationLimit),
                      minuteInterval: 5,
                      use24hFormat: true,
                      dateOrder: DatePickerDateOrder.dmy,
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return await _showMaterialDatePicker(now, durationLimit);
      },
    );
  }

  // This function displays a CupertinoModalPopup with a reasonable fixed height
  // which hosts CupertinoDatePicker.
  void _showDialog(BuildContext context, Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        constraints: const BoxConstraints.expand(height: 216.0),
        // The Bottom margin is provided to align the popup above the system
        // navigation bar.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        // Provide a background color for the popup.
        color: CupertinoColors.systemBackground.resolveFrom(context),
        // Use a SafeArea widget to avoid system overlaps.
        child: SafeArea(top: false, child: child),
      ),
    );
  }

  Future<void> _showMaterialDatePicker(
    DateTime now,
    Duration durationLimit,
  ) async {
    switch (widget.mode) {
      case SuggestionDateChipMode.date:
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: widget.initialDate ?? now,
          firstDate: widget.firstDate ?? now.subtract(durationLimit),
          lastDate: now.add(durationLimit),
        );

        if (selectedDate != null) {
          widget.onDatePicked.call(selectedDate);
        }
      case SuggestionDateChipMode.time:
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
        );

        if (selectedTime != null) {
          widget.onDatePicked.call(
            now.copyWith(hour: selectedTime.hour, minute: selectedTime.minute),
          );
        }
    }
  }
}
