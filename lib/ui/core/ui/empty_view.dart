import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.icon, required this.text, this.action});

  const EmptyView.error({super.key, required this.text, this.action})
    : icon = const Icon(Icons.cancel_outlined, color: Colors.redAccent);

  const EmptyView.loading({super.key, this.text})
    : icon = const CustomCircularProgressIndicator(),
      action = null;

  final Widget? icon;
  final Widget? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                16.0,
                16.0,
                16.0,
                8.0,
              ),
              child: IconTheme.merge(
                data: const IconThemeData(size: 40.0, opticalSize: 80.0),
                child: icon!,
              ),
            ),
          if (text != null)
            SizedBox(
              width: MediaQuery.sizeOf(context).width / 2,
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyLarge!,
                textAlign: TextAlign.center,
                child: text!,
              ),
            ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
