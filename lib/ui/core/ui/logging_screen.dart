import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

class LoggingScreen extends StatelessWidget {
  const LoggingScreen({required this.talker, super.key});

  final Talker talker;

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(
      talker: talker,
      appBarTitle: 'Logs',
    );
  }
}
