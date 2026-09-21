import 'package:material_ui/material_ui.dart';
import 'package:talker_flutter/talker_flutter.dart';

class LoggingScreen extends StatelessWidget {
  const LoggingScreen({required this.talker, super.key});

  final Talker talker;

  @override
  Widget build(BuildContext context) {
    // TODO(xmattjus): Remove the bridge when talker_flutter
    //  migrates to package:material_ui.
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: TalkerScreen(talker: talker, appBarTitle: 'Logs'),
    );
  }
}
