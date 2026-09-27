import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({required this.text, this.icon, this.action, super.key});

  const EmptyView.error({required this.text, this.action, super.key})
    : icon = const Icon(Symbols.cancel, color: Colors.redAccent);

  const EmptyView.loading({this.text, super.key})
    : icon = const CustomCircularProgressIndicator(),
      action = null;

  final Widget? icon;
  final Widget? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                child: IconTheme.merge(
                  data: const IconThemeData(size: 40, opticalSize: 80),
                  child: icon!,
                ),
              ),
            if (text != null)
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyLarge!,
                textAlign: TextAlign.center,
                child: text!,
              ),
            ?action,
          ],
        ),
      ),
    );
  }
}
