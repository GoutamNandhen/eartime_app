import 'package:flutter/material.dart';
import '../listening/listening_workspace.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ListeningWorkspace(view: ListeningView.analytics);
}
