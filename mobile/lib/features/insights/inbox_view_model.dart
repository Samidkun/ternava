import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_failure.dart';
import '../../core/api/generated/types.dart';

/// The server-side access gate. Opening a target must never rely on a client
/// decision: the server is asked whether this actor may still see the target.
abstract class TargetAccess {
  Future<void> requireAccess(String resourceType, String resourceId);
}

enum InboxState { idle, targetUnavailable }

class InboxItemView {
  final String id;
  final int version;
  final String kind;
  final String title;
  final String body;
  final String resourceType;
  final String resourceId;
  final String? readAt;

  const InboxItemView({
    required this.id,
    required this.version,
    required this.kind,
    required this.title,
    required this.body,
    required this.resourceType,
    required this.resourceId,
    required this.readAt,
  });

  bool get isUnread => readAt == null;

  /// The deep-link target. Only a screen id and a resource id are derived —
  /// never an arbitrary URL, which the client would otherwise have to fetch.
  String get screenId {
    switch (resourceType) {
      case 'task_run':
        return 'task-detail';
      case 'daily':
        return 'daily-detail';
      case 'feed_type':
        return 'feed-detail';
      case 'incident':
      default:
        return 'incident-detail';
    }
  }

  factory InboxItemView.fromJson(JsonObject json) => InboxItemView(
    id: json['id'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? 1,
    kind: json['kind'] as String? ?? 'incident',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    resourceType: json['resource_type'] as String? ?? 'incident',
    resourceId: json['resource_id'] as String? ?? '',
    readAt: json['read_at'] as String?,
  );
}

class InboxViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  final TargetAccess targets;
  final Future<void> Function(String screenId, String resourceId) onOpen;

  List<InboxItemView> _items = [];
  InboxState _state = InboxState.idle;
  bool _isLoading = false;
  String? _errorMessage;

  InboxViewModel({
    required this.apiClient,
    required this.targets,
    required this.onOpen,
  });

  List<InboxItemView> get items => _items;
  InboxState get state => _state;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _items.where((i) => i.isUnread).length;

  /// Test seam: seed the list without a network round-trip.
  @visibleForTesting
  void setItemsForTest(List<InboxItemView> items) {
    _items = items;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await apiClient.request('listInbox');
      final data = (response['data'] as List<dynamic>?) ?? [];
      _items = data
          .whereType<Map<String, dynamic>>()
          .map((raw) => InboxItemView.fromJson(Map<String, Object?>.from(raw)))
          .toList();
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Confirms access with the server, then opens the target. A revoked or
  /// deleted target yields 404/403 and lands on a recoverable state instead of
  /// a dead end.
  Future<void> open(String itemId) async {
    final item = _itemById(itemId);
    if (item == null) return;

    _state = InboxState.idle;
    notifyListeners();

    try {
      await targets.requireAccess(item.resourceType, item.resourceId);
    } on ApiFailure catch (e) {
      if (e.status == 404 || e.status == 403) {
        _state = InboxState.targetUnavailable;
        notifyListeners();
        return;
      }
      rethrow;
    }

    await markRead(itemId);
    await onOpen(item.screenId, item.resourceId);
  }

  Future<void> markRead(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final item = _items[index];

    try {
      await apiClient.request(
        'readInbox',
        pathParams: {'id': itemId},
        idempotencyKey: 'inbox-read-$itemId',
      );
    } on ApiFailure catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return;
    }

    // Idempotent: an already-read item stays read; a first read becomes read.
    if (item.isUnread) {
      _items[index] = InboxItemView(
        id: item.id,
        version: item.version + 1,
        kind: item.kind,
        title: item.title,
        body: item.body,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
        readAt: DateTime.now().toIso8601String(),
      );
    }
    notifyListeners();
  }

  InboxItemView? _itemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
