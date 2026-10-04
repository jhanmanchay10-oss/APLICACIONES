import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistant/assistant_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../weekly/weekly_screen.dart';

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

abstract final class AppTab {
  static const home = 0;
  static const history = 1;
  static const assistant = 2;
  static const weekly = 3;
  static const profile = 4;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _pages = [
    HomeScreen(),
    HistoryScreen(),
    AssistantScreen(),
    WeeklyScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    return PopScope(
      canPop: index == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(tabIndexProvider.notifier).select(AppTab.home);
      },
      child: Scaffold(
        body: IndexedStack(index: index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: ref.read(tabIndexProvider.notifier).select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(
                icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Historial'),
            NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Nutri IA'),
            NavigationDestination(
                icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Semana'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
