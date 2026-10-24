import 'package:flutter/material.dart';
import '../listening/listening_workspace.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ListeningWorkspace(view: ListeningView.timeline);
}
