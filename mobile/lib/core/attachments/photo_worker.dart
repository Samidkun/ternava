import 'dart:typed_data';

import 'photo_repository.dart';

/// Knows whether a parent object has been acknowledged by the server.
/// Photos must never upload before their parent is accepted.
abstract class ParentAcceptance {
  bool isAccepted(String parentId);
}

/// Sends a photo's original bytes to the server.
abstract class PhotoUploader {
  Future<void> send(String operationId, String sha256, Uint8List bytes);
}

class PhotoWorker {
  final PhotoRepository repository;
  final ParentAcceptance parents;
  final PhotoUploader uploader;

  PhotoWorker({
    required this.repository,
    required this.parents,
    required this.uploader,
  });

  Future<void> runOnce() async {
    final photos = await repository.pending();

    for (final photo in photos) {
      if (photo.state == PhotoState.uploaded) continue;

      // Gate: only upload after the parent has been acknowledged.
      if (!parents.isAccepted(photo.parentId)) {
        continue;
      }

      await repository.markState(photo.operationId, PhotoState.uploading);

      try {
        final bytes = await repository.cipher
            .decrypt(photo.encryptedBytes, photo.aad);
        await uploader.send(photo.operationId, photo.sha256, bytes);
        await repository.markState(photo.operationId, PhotoState.uploaded);
      } catch (_) {
        // A failed photo is kept (not discarded) so it can be retried; the
        // parent text is never rolled back.
        await repository.markState(photo.operationId, PhotoState.failed);
      }
    }
  }
}
