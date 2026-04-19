import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppView { setup, planner, execution, postSession, calendar, library }

final selectedViewProvider = StateProvider<AppView>((ref) => AppView.planner);
