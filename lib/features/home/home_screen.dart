import 'package:flutter/material.dart';
import '../listening/listening_workspace.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ListeningWorkspace(view: ListeningView.home);
}
