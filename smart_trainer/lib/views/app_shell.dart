import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
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
    final settingsAsync = ref.watch(settingsProvider);

    final isConfigured = settingsAsync.maybeWhen(
      data: (s) => s.isConfigured,
      orElse: () => false,
    );

    final effectiveIndex = isConfigured ? selected.index : AppView.setup.index;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: effectiveIndex,
            onDestinationSelected: (i) {
              if (!isConfigured && i != AppView.setup.index) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter your FTP in Setup before using the app'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              ref.read(selectedViewProvider.notifier).state = AppView.values[i];
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Setup'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_outlined,
                    color: isConfigured ? null : Colors.white24),
                selectedIcon: const Icon(Icons.edit),
                label: Text('Planner',
                    style: TextStyle(
                        color: isConfigured ? null : Colors.white24)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.play_circle_outline,
                    color: isConfigured ? null : Colors.white24),
                selectedIcon: const Icon(Icons.play_circle),
                label: Text('Ride',
                    style: TextStyle(
                        color: isConfigured ? null : Colors.white24)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined,
                    color: isConfigured ? null : Colors.white24),
                selectedIcon: const Icon(Icons.checklist),
                label: Text('Review',
                    style: TextStyle(
                        color: isConfigured ? null : Colors.white24)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined,
                    color: isConfigured ? null : Colors.white24),
                selectedIcon: const Icon(Icons.calendar_month),
                label: Text('Calendar',
                    style: TextStyle(
                        color: isConfigured ? null : Colors.white24)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books_outlined,
                    color: isConfigured ? null : Colors.white24),
                selectedIcon: const Icon(Icons.library_books),
                label: Text('Library',
                    style: TextStyle(
                        color: isConfigured ? null : Colors.white24)),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: isConfigured ? _body(selected) : const SetupView(),
          ),
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
