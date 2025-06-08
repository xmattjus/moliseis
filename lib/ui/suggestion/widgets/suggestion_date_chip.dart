import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SuggestionDateChip extends StatelessWidget {
  const SuggestionDateChip({
    super.key,
    this.firstDate,
    this.initialDate,
    required this.label,
    required this.onDatePicked,
  });

  final DateTime? firstDate;
  final DateTime? initialDate;
  final Widget label;
  final void Function(DateTime?) onDatePicked;

  @override
  Widget build(BuildContext context) {
    // The lower and upper bounds of selectable dates.
    const durationLimit = Duration(days: 365 * 3);

    return RawChip(
      label: label,
      onPressed: () async {
        if (Platform.isIOS) {
          _showDialog(
            context,
            CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              onDateTimeChanged: (value) => onDatePicked(value),
              initialDateTime: initialDate ?? DateTime.now(),
              minimumDate: firstDate ?? DateTime.now().subtract(durationLimit),
              maximumDate: DateTime.now().add(durationLimit),
              dateOrder: DatePickerDateOrder.dmy,
            ),
          );
        } else {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: initialDate ?? DateTime.now(),
            firstDate: firstDate ?? DateTime.now().subtract(durationLimit),
            lastDate: DateTime.now().add(durationLimit),
          );

          if (pickedDate != null) {
            onDatePicked.call(pickedDate);
          }
        }
      },
    );
  }

  // This function displays a CupertinoModalPopup with a reasonable fixed height
  // which hosts CupertinoDatePicker.
  void _showDialog(BuildContext context, Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
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
}
