import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

enum ContentSubmissionDateChipMode { date, time }

class ContentSubmissionDateChip extends StatefulWidget {
  const ContentSubmissionDateChip({
    super.key,
    this.firstDate,
    this.initialDate,
    required this.label,
    this.leading,
    this.mode = ContentSubmissionDateChipMode.date,
    required this.onDatePicked,
  });

  final DateTime? firstDate;
  final DateTime? initialDate;
  final Widget label;
  final Widget? leading;
  final ContentSubmissionDateChipMode mode;
  final void Function(DateTime? date) onDatePicked;

  @override
  State<ContentSubmissionDateChip> createState() =>
      _ContentSubmissionDateChipState();
}

class _ContentSubmissionDateChipState extends State<ContentSubmissionDateChip> {
  DateTime? _selectedDateTime;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // The lower and upper bounds of selectable dates.
    final firstDate = DateTime(now.year);
    final lastDate = DateTime(now.year, 12, 31).endOfDay;

    return InputChip(
      avatar: widget.leading,
      label: widget.label,
      onPressed: () async {
        if (Platform.isIOS) {
          if (context.windowSizeClass.isCompact) {
            // Seed the pending selection so that confirming without scrolling
            // the wheel still selects the initial date shown by the picker.
            // Without this, `_selectedDateTime` stays null until the first
            // `onDateTimeChanged` event and the Conferma button would close
            // the modal without emitting a value.
            _selectedDateTime =
                widget.initialDate ?? now.copyWith(minute: now.minute % 5 * 5);
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
                          onPressed: () => context.pop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.mode == ContentSubmissionDateChipMode.date
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
                            context.pop();
                          },
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: CupertinoDatePicker(
                      mode: widget.mode == ContentSubmissionDateChipMode.date
                          ? CupertinoDatePickerMode.date
                          : CupertinoDatePickerMode.time,
                      onDateTimeChanged: (value) => _selectedDateTime = value,
                      initialDateTime:
                          widget.initialDate ??
                          now.copyWith(minute: now.minute % 5 * 5),
                      minimumDate: widget.firstDate ?? firstDate,
                      maximumDate: lastDate,
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

        return _showMaterialDatePicker(now, firstDate, lastDate);
      },
    );
  }

  // This function displays a CupertinoModalPopup with a reasonable fixed height
  // which hosts CupertinoDatePicker.
  Future<void> _showDialog(BuildContext context, Widget child) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        constraints: const BoxConstraints.expand(height: 216),
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
    DateTime firstDate,
    DateTime lastDate,
  ) async {
    switch (widget.mode) {
      case ContentSubmissionDateChipMode.date:
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: widget.initialDate ?? now,
          firstDate: widget.firstDate ?? firstDate,
          lastDate: lastDate,
        );

        if (selectedDate != null) {
          widget.onDatePicked.call(selectedDate);
        }
      case ContentSubmissionDateChipMode.time:
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
