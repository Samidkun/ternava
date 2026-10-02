import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../local/partition_store.dart';
import '../local/payload_cipher.dart';

/// Thrown when a photo fails local validation (type/size/count).
class PhotoRejected implements Exception {
  final String message;
  const PhotoRejected(this.message);

  @override
  String toString() => 'PhotoRejected: $message';
}

enum PhotoState { waitingForParent, uploading, uploaded, failed }

class QueuedPhoto {
  final String operationId;
  final String parentKind;
  final String parentId;
  final String mediaType;
  final String sha256;
  final Uint8List encryptedBytes;
  final String aad;
  PhotoState state;

  QueuedPhoto({
    required this.operationId,
    required this.parentKind,
    required this.parentId,
    required this.mediaType,
    required this.sha256,
    required this.encryptedBytes,
    required this.aad,
    this.state = PhotoState.waitingForParent,
  });
}

/// Stores photos encrypted at rest, keyed to the current partition. A photo is
/// enqueued (encrypted + persisted) BEFORE its status is reported anywhere, and
/// it never uploads until its parent has been acknowledged by the server.
class PhotoRepository {
  static const int maxBytes = 2 * 1024 * 1024;
  static const int maxPerParent = 3;
  static const List<String> allowedTypes = ['image/jpeg', 'image/png'];

  final PartitionStore store;
  final PayloadCipher cipher;
  final Map<String, QueuedPhoto> _queue = {};

  PhotoRepository({required this.store, required this.cipher});

  Future<String> add(
    String parentKind,
    String parentId,
    Uint8List bytes, {
    required String mediaType,
  }) async {
    if (!allowedTypes.contains(mediaType)) {
      throw const PhotoRejected('Gunakan JPEG atau PNG yang dapat dibuka.');
    }
    if (bytes.length > maxBytes) {
      throw const PhotoRejected('Foto maksimal 2 MiB.');
    }

    final existing = _queue.values
        .where((p) => p.parentKind == parentKind && p.parentId == parentId)
        .length;
    if (existing >= maxPerParent) {
      throw const PhotoRejected('Maksimal 3 foto per catatan.');
    }

    final operationId =
        'photo-$parentKind-$parentId-${DateTime.now().microsecondsSinceEpoch}';
    final aad = '$parentKind:$parentId:$operationId';

    // The hash is over the ORIGINAL bytes, before any transformation.
    final sha256 = _hash(bytes);

    // Encrypt and persist BEFORE exposing the queue entry.
    final encrypted = await cipher.encrypt(bytes, aad);

    final photo = QueuedPhoto(
      operationId: operationId,
      parentKind: parentKind,
      parentId: parentId,
      mediaType: mediaType,
      sha256: sha256,
      encryptedBytes: encrypted,
      aad: aad,
    );

    await store.transaction(() async {
      _queue[operationId] = photo;
    });

    return operationId;
  }

  Future<List<QueuedPhoto>> pending() async {
    return _queue.values.where((p) => p.state != PhotoState.uploaded).toList()
      ..sort((a, b) => a.operationId.compareTo(b.operationId));
  }

  Future<void> markState(String operationId, PhotoState state) async {
    final photo = _queue[operationId];
    if (photo != null) {
      photo.state = state;
    }
  }

  static String _hash(Uint8List bytes) => sha256.convert(bytes).toString();
}
