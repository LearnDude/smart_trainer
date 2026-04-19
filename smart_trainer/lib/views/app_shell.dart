import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import 'setup/setup_view.dart';
import 'planner/planner_view.dart';
import 'execution/execution_view.dart';
import 'post_session/post_session_view.dart';
import 'calendar/calendar_view.dart';
import 'library/library_view.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedViewProvider);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected.index,
            onDestinationSelected: (i) {
              ref.read(selectedViewProvider.notifier).state = AppView.values[i];
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Setup'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_outlined),
                selectedIcon: Icon(Icons.edit),
                label: Text('Planner'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.play_circle_outline),
                selectedIcon: Icon(Icons.play_circle),
                label: Text('Ride'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: Text('Review'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('Calendar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: Text('Library'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _body(selected)),
        ],
      ),
    );
  }

  Widget _body(AppView view) {
    return switch (view) {
      AppView.setup => const SetupView(),
      AppView.planner => const PlannerView(),
      AppView.execution => const ExecutionView(),
      AppView.postSession => const PostSessionView(),
      AppView.calendar => const CalendarView(),
      AppView.library => const LibraryView(),
    };
  }
}
