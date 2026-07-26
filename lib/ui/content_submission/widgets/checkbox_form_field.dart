import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

class CheckboxFormField extends FormField<bool> {
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
                     12,
                     2,
                     12,
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
