import 'package:flutter/material.dart';

class GlassNavigation extends StatelessWidget {
  const GlassNavigation({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: currentIndex,
    onDestinationSelected: onIndexChanged,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        label: 'Analytics',
      ),
      NavigationDestination(icon: Icon(Icons.history), label: 'Timeline'),
      NavigationDestination(
        icon: Icon(Icons.favorite_outline),
        label: 'Wellbeing',
      ),
      NavigationDestination(
        icon: Icon(Icons.headphones_outlined),
        label: 'Devices',
      ),
    ],
  );
}
