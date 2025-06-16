import 'package:flutter/material.dart';

class CheckboxFormField extends FormField<bool> {
  CheckboxFormField({
    Widget? title,
    super.onSaved,
    super.validator,
    bool super.initialValue = false,
    super.autovalidateMode,
  }) : super(
         builder: (FormFieldState<bool> state) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 spacing: 24.0,
                 children: [
                   Checkbox(
                     value: state.value,
                     onChanged: state.didChange,
                     visualDensity: const VisualDensity(
                       horizontal: VisualDensity.minimumDensity,
                       vertical: VisualDensity.minimumDensity,
                     ),
                     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                   ),
                   Expanded(child: title ?? const SizedBox()),
                 ],
               ),
               if (state.hasError)
                 Padding(
                   padding: const EdgeInsetsDirectional.fromSTEB(
                     12.0,
                     2.0,
                     12.0,
                     0.0,
                   ),
                   child: Builder(
                     builder: (context) {
                       return Text(
                         state.errorText ?? "",
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
