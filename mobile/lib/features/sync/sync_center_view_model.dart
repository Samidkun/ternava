import 'package:flutter/foundation.dart';

import '../../core/sync/cache_repository.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/sync_worker.dart';
import '../../ui/navigation/app_router.dart';

class SyncCenterViewModel extends ChangeNotifier {
  final OutboxRepository outbox;
  final SyncWorker worker;
  final CacheRepository cache;

  List<Intent> _items = [];
  bool _isBusy = false;

  SyncCenterViewModel({
    required this.outbox,
    required this.worker,
    required this.cache,
  });

  List<Intent> get items => _items;
  bool get isBusy => _isBusy;

  int get blockedAuthCount =>
      _items.where((i) => i.lastError != null && i.state == IntentState.pending).length;

  Future<void> load() async {
    _items = await outbox.allIntents();
    notifyListeners();
  }

  Future<void> retry(String operationId) async {
    _isBusy = true;
    notifyListeners();

    final target =
        _items.where((i) => i.id == operationId || i.operationId == operationId);
    if (target.isEmpty) {
      _isBusy = false;
      notifyListeners();
      return;
    }

    final intent = target.first;

    // Blocked auth: do not hammer the server, route to login instead.
    if (intent.state == IntentState.pending &&
        intent.lastError != null &&
        intent.lastError!.contains('auth')) {
      await reauthenticate();
      _isBusy = false;
      notifyListeners();
      return;
    }

    await outbox.retryIntent(intent.id);
    await worker.runOnce();
    await load();
    _isBusy = false;
    notifyListeners();
  }

  Future<void> reauthenticate() async {
    await AppRouter.open('login');
  }

  Future<void> cancelDraft(String operationId, {required bool confirmed}) async {
    if (!confirmed) return;
    final target = _items
        .where((i) => i.id == operationId || i.operationId == operationId);
    if (target.isEmpty) return;
    await outbox.cancelIntent(target.first.id);
    await load();
    notifyListeners();
  }
}
