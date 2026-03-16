import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'insert_tab.dart';
import 'management_tab.dart';
import '../providers/ui_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _pages = [const InsertTab(), const ManagementTab()];

  @override
  Widget build(BuildContext context) {
    final uiProvider = Provider.of<UiProvider>(context);

    return Scaffold(
      extendBody:
          false, // Standard layout avoids overlap issues with NavigationRail
      appBar: AppBar(title: const Text('تطبيق إدارة البيانات')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Tablet/Desktop: NavigationRail
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: uiProvider.selectedIndex,
                  onDestinationSelected: (int index) {
                    uiProvider.setTabIndex(index);
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  selectedIconTheme: IconThemeData(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: Colors.grey.shade400,
                  ),
                  selectedLabelTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.fontFamily,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.fontFamily,
                  ),
                  destinations: const <NavigationRailDestination>[
                    NavigationRailDestination(
                      icon: Icon(Icons.add_circle_outline),
                      selectedIcon: Icon(Icons.add_circle),
                      label: Text('إدخال'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('الإدارة'),
                    ),
                  ],
                ),
                VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: IndexedStack(
                    index: uiProvider.selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            );
          } else {
            // Mobile: BottomNavigationBar
            return IndexedStack(
              index: uiProvider.selectedIndex,
              children: _pages,
            );
          }
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width > 800
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: uiProvider.selectedIndex,
                onDestinationSelected: (index) => uiProvider.setTabIndex(index),
                backgroundColor: Colors.white,
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.add_circle_outline),
                    selectedIcon: Icon(Icons.add_circle),
                    label: 'إدخال',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'الإدارة',
                  ),
                ],
              ),
            ),
    );
  }
}
