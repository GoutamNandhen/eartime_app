import 'package:flutter/material.dart';
import '../listening/listening_workspace.dart';

class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ListeningWorkspace(view: ListeningView.wellbeing);
}
