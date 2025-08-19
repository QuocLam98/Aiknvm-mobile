import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../tabs/home_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/search_tab.dart';
import 'widgets/app_drawer.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final DashboardController controller;

  @override
  void initState() {
    super.initState();
    controller = DashboardController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      HomeTab(),
      SearchTab(),
      ProfileTab(),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: controller.currentIndex,
      builder: (context, index, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chat App'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => controller.openSettings(context),
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: IndexedStack(index: index, children: pages),
          floatingActionButton: FloatingActionButton(
            onPressed: () => controller.onFabPressed(context),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: controller.setIndex,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Search'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}
