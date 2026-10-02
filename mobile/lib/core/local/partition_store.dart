import 'dart:async';
import 'package:flutter/foundation.dart';

@immutable
class PartitionId {
  final String actorId;
  final String farmId;

  const PartitionId({
    required this.actorId,
    required this.farmId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartitionId &&
          actorId == other.actorId &&
          farmId == other.farmId;

  @override
  int get hashCode => Object.hash(actorId, farmId);

  @override
  String toString() => 'PartitionId($farmId:$actorId)';
}

class PartitionStore {
  PartitionId? _currentPartition;
  bool _isUnlocked = false;

  bool get isUnlocked => _isUnlocked;
  PartitionId? get currentPartition => _currentPartition;

  Future<void> unlock(PartitionId id) async {
    _currentPartition = id;
    _isUnlocked = true;
  }

  Future<void> lock() async {
    _currentPartition = null;
    _isUnlocked = false;
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    if (!_isUnlocked || _currentPartition == null) {
      throw StateError(
          'PartitionStore terkunci. Buka kunci partisi sebelum melakukan transaksi.');
    }
    return await action();
  }
}
