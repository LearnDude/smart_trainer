import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_result.dart';
import '../services/database_service.dart';

class SessionHistoryNotifier extends AsyncNotifier<List<SessionResult>> {
  @override
  Future<List<SessionResult>> build() =>
      ref.read(databaseServiceProvider).queryAllSessionResults();

  Future<int> save(SessionResult result) async {
    final id = await ref.read(databaseServiceProvider).insertSessionResult(result);
    ref.invalidateSelf();
    return id;
  }
}

final sessionHistoryProvider =
    AsyncNotifierProvider<SessionHistoryNotifier, List<SessionResult>>(
        SessionHistoryNotifier.new);
