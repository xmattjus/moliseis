import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

/// A `FormField` that wraps a `Checkbox` with an optional label and error
/// display beneath it.
///
/// The field integrates with Flutter's form validation system and passes the
/// boolean value to `onChanged` after running the validator on the new value.
class CheckboxFormField extends FormField<bool> {
  /// Creates a checkbox-backed form field.
  ///
  /// `title` is displayed beside the checkbox. `onChanged` is called with the
  /// new boolean value each time the checkbox state changes.
  CheckboxFormField({
    Widget? title,
    super.onSaved,
    super.validator,
    bool super.initialValue = false,
    super.autovalidateMode,
    ValueChanged<bool?>? onChanged,
    super.key,
  }) : super(
         builder: (state) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 spacing: 24,
                 children: [
                   Checkbox(
                     value: state.value,
                     onChanged: (value) {
                       // `didChange` first so the validator (if any) runs on
                       // the new value before any external listener observes
                       // a stale one.
                       state.didChange(value);
                       onChanged?.call(value);
                     },
                     visualDensity: const VisualDensity(
                       horizontal: VisualDensity.minimumDensity,
                       vertical: VisualDensity.minimumDensity,
                     ),
                   ),
                   Expanded(child: title ?? const EmptyBox()),
                 ],
               ),
               if (state.hasError)
                 Padding(
                   padding: const EdgeInsetsDirectional.fromSTEB(
                     16,
                     2,
                     16,
                     0,
                   ),
                   child: Builder(
                     builder: (context) {
                       return Text(
                         state.errorText ?? '',
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: Theme.of(context).colorScheme.error,
                         ),
                       );
                     },
                   ),
                 ),
             ],
           );
         },
       );
}
