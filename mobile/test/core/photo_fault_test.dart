import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/attachments/photo_repository.dart';
import 'package:mobile/core/attachments/photo_worker.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/local/payload_cipher.dart';

/// A parent ACK registry: photos may only upload after their parent is accepted.
class FakeParents implements ParentAcceptance {
  final Set<String> accepted = {};
  @override
  bool isAccepted(String parentId) => accepted.contains(parentId);
}

/// A counting uploader that can be made to fail on demand.
class FakeUploader implements PhotoUploader {
  final List<String> sentKeys = [];
  final List<String> sentHashes = [];
  int failNext = 0;

  @override
  Future<void> send(String operationId, String sha256, Uint8List bytes) async {
    if (failNext > 0) {
      failNext -= 1;
      throw Exception('upload failed');
    }
    sentKeys.add(operationId);
    sentHashes.add(sha256);
  }
}

Future<PartitionId> unlockedStore(PartitionStore store) async {
  const pid = PartitionId(actorId: 'op-1', farmId: 'farm-1');
  await store.unlock(pid);
  return pid;
}

void main() {
  group('T36 Photo queue tests', () {
    test('upload tidak berjalan sebelum parent ACK', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);
      final parents = FakeParents();
      final uploader = FakeUploader();

      await repo.add('incident', 'inc-1', Uint8List.fromList([1, 2, 3, 4]),
          mediaType: 'image/jpeg');

      final worker = PhotoWorker(
        repository: repo,
        parents: parents,
        uploader: uploader,
      );

      await worker.runOnce();
      expect(uploader.sentKeys, isEmpty, reason: 'parent belum ACK');

      parents.accepted.add('inc-1');
      await worker.runOnce();
      expect(uploader.sentKeys, hasLength(1));
    });

    test('foto tersimpan terenkripsi sebelum status dikirim', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);

      final original = Uint8List.fromList([9, 8, 7, 6, 5]);
      await repo.add('incident', 'inc-1', original, mediaType: 'image/jpeg');

      final pending = await repo.pending();
      expect(pending, hasLength(1));
      // The stored bytes must not be the plaintext.
      expect(pending.first.encryptedBytes, isNot(equals(original)));
      expect(pending.first.state, PhotoState.waitingForParent);
    });

    test('hash dihitung atas byte asli dan stabil saat retry', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);
      final parents = FakeParents()..accepted.add('inc-1');
      final uploader = FakeUploader()..failNext = 1;

      final original = Uint8List.fromList([1, 2, 3]);
      await repo.add('incident', 'inc-1', original, mediaType: 'image/jpeg');

      final worker = PhotoWorker(
        repository: repo,
        parents: parents,
        uploader: uploader,
      );

      await worker.runOnce(); // fails
      final afterFail = await repo.pending();
      expect(afterFail.first.state, PhotoState.failed);
      final hashAfterFail = afterFail.first.sha256;

      await worker.runOnce(); // retry succeeds
      expect(uploader.sentHashes, hasLength(1));
      expect(uploader.sentHashes.first, hashAfterFail);
      // The operation key is stable across retries.
      expect(uploader.sentKeys.first, afterFail.first.operationId);
    });

    test('maksimal tiga foto per induk', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);

      for (var i = 0; i < 3; i++) {
        await repo.add('incident', 'inc-1', Uint8List.fromList([i]),
            mediaType: 'image/jpeg');
      }

      expect(
        () => repo.add('incident', 'inc-1', Uint8List.fromList([9]),
            mediaType: 'image/jpeg'),
        throwsA(isA<PhotoRejected>()),
      );
    });

    test('tipe dan ukuran tidak valid ditolak lokal', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);

      expect(
        () => repo.add('incident', 'inc-1', Uint8List.fromList([1]),
            mediaType: 'text/plain'),
        throwsA(isA<PhotoRejected>()),
      );

      final tooBig = Uint8List(3 * 1024 * 1024);
      expect(
        () => repo.add('incident', 'inc-1', tooBig, mediaType: 'image/jpeg'),
        throwsA(isA<PhotoRejected>()),
      );
    });

    test('foto gagal tetap ada untuk dipulihkan, teks tidak hilang', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);
      final parents = FakeParents()..accepted.add('inc-1');
      final uploader = FakeUploader()..failNext = 99;

      await repo.add('incident', 'inc-1', Uint8List.fromList([1, 2]),
          mediaType: 'image/jpeg');

      final worker = PhotoWorker(
        repository: repo,
        parents: parents,
        uploader: uploader,
      );
      await worker.runOnce();

      final remaining = await repo.pending();
      expect(remaining, hasLength(1));
      expect(remaining.first.state, PhotoState.failed);
    });

    test('relogin membuka partisi yang benar dan bisa mendekripsi', () async {
      final store = PartitionStore();
      final pid = await unlockedStore(store);
      final cipher = await PayloadCipher.forPartition(pid);
      final repo = PhotoRepository(store: store, cipher: cipher);

      final original = Uint8List.fromList([4, 4, 4]);
      await repo.add('incident', 'inc-1', original, mediaType: 'image/jpeg');

      // Lock and re-unlock the same partition (simulated relogin).
      await store.lock();
      await store.unlock(pid);

      final pending = await repo.pending();
      final decrypted = await cipher.decrypt(
        pending.first.encryptedBytes,
        pending.first.aad,
      );
      expect(decrypted, equals(original));
    });
  });
}
