import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/local/payload_cipher.dart';
import 'package:mobile/core/session/offline_lease.dart';

void main() {
  group('PayloadCipher & PartitionStore tests', () {
    test('akun B gagal decrypt payload A (PartitionMismatch)', () async {
      final partitionA = const PartitionId(
        actorId: 'actor-a',
        farmId: 'farm-1',
      );
      final partitionB = const PartitionId(
        actorId: 'actor-b',
        farmId: 'farm-1',
      );

      final cipherA = await PayloadCipher.forPartition(partitionA);
      final cipherB = await PayloadCipher.forPartition(partitionB);

      final payload = utf8.encode('Catatan rahasia operator A');
      final encrypted = await cipherA.encrypt(
        Uint8List.fromList(payload),
        'daily_record:uuid-123',
      );

      // Decrypting with matching cipher A succeeds
      final decrypted = await cipherA.decrypt(
        encrypted,
        'daily_record:uuid-123',
      );
      expect(utf8.decode(decrypted), 'Catatan rahasia operator A');

      // Decrypting with cipher B fails with PartitionMismatch exception
      expect(
        () => cipherB.decrypt(encrypted, 'daily_record:uuid-123'),
        throwsA(isA<PartitionMismatch>()),
      );

      // Decrypting with wrong AAD also fails with PartitionMismatch
      expect(
        () => cipherA.decrypt(encrypted, 'daily_record:wrong-id'),
        throwsA(isA<PartitionMismatch>()),
      );
    });

    test('PartitionStore locks and unlocks transactions', () async {
      final store = PartitionStore();
      final partition = const PartitionId(
        actorId: 'actor-test',
        farmId: 'farm-test',
      );

      expect(store.isUnlocked, false);

      await store.unlock(partition);
      expect(store.isUnlocked, true);
      expect(store.currentPartition, partition);

      var executed = false;
      final result = await store.transaction(() async {
        executed = true;
        return 'success';
      });

      expect(executed, true);
      expect(result, 'success');

      await store.lock();
      expect(store.isUnlocked, false);

      expect(
        () => store.transaction(() async => 'blocked'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('OfflineLease tests', () {
    test('offline lease allows write within 24 hours', () {
      final issuedAt = DateTime.parse('2026-10-01T08:00:00Z');
      final expiresAt = issuedAt.add(const Duration(hours: 24));
      final lease = OfflineLease(
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        initialMonotonic: const Duration(seconds: 100),
      );

      // Within 24 hours and monotonic clock advancing -> can write
      final validTime = issuedAt.add(const Duration(hours: 5));
      expect(lease.canWrite(validTime, const Duration(seconds: 18100)), true);

      // Past 24 hours -> cannot write
      final expiredTime = issuedAt.add(const Duration(hours: 25));
      expect(
        lease.canWrite(expiredTime, const Duration(seconds: 90100)),
        false,
      );

      // Clock rollback (monotonic or wall clock rewound) -> locked
      final rollbackWall = issuedAt.subtract(const Duration(hours: 1));
      expect(
        lease.canWrite(rollbackWall, const Duration(seconds: 18100)),
        false,
      );
    });
  });
}
