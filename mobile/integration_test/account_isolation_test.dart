// T42 — account isolation and session lock, run on a real Android device.
//
// Covers AC-24, AC-35, AC-33, AC-34: account A's queued work survives a
// confirmed logout, account B cannot read A's data, and an expired offline
// lease stops writes. These exercise the REAL production store/cipher/outbox.
// The true OS-process-kill and TalkBack checks are recorded in
// docs/evidence/android-uat.md and are NOT claimed as passing here.
//
// Run: cd mobile && flutter test integration_test/account_isolation_test.dart -d <DEVICE_ID>

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/local/payload_cipher.dart';
import 'package:mobile/core/session/offline_lease.dart';

import 'support/mobile_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logout terkonfirmasi mengunci partisi namun antrean tetap ada',
      (tester) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();
    s.transport.offline = true;
    await s.enqueueDaily();

    expect(s.store.isUnlocked, true);
    final pendingBefore = await s.pendingIds();
    expect(pendingBefore, hasLength(1));

    // Cancel does NOT lock.
    await s.logout(confirmed: false);
    expect(s.store.isUnlocked, true);

    // Confirm locks the partition.
    await s.logout(confirmed: true);
    expect(s.store.isUnlocked, false);

    // Local transactions are refused while locked...
    await expectLater(
      s.store.transaction(() async => 'blocked'),
      throwsA(isA<StateError>()),
    );

    // ...but the queued intent was preserved for a later re-login.
    await s.loginAsOperator();
    expect(await s.pendingIds(), hasLength(1));
  });

  testWidgets('akun B tidak dapat mendekripsi payload akun A', (tester) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();

    final cipherA = await PayloadCipher.forPartition(
      const PartitionId(actorId: 'operator-budi', farmId: 'farm-test-01'),
    );
    final cipherB = await PayloadCipher.forPartition(
      const PartitionId(actorId: 'operator-sari', farmId: 'farm-test-01'),
    );

    final encrypted = await cipherA.encrypt(
      Uint8List.fromList('Catatan rahasia operator A'.codeUnits),
      'daily_record:uuid-123',
    );

    // A can decrypt its own payload.
    final clear = await cipherA.decrypt(encrypted, 'daily_record:uuid-123');
    expect(String.fromCharCodes(clear), 'Catatan rahasia operator A');

    // B cannot — the partition is bound into the AEAD.
    await expectLater(
      cipherB.decrypt(encrypted, 'daily_record:uuid-123'),
      throwsA(isA<PartitionMismatch>()),
    );
  });

  testWidgets('lease kedaluwarsa atau jam mundur menghentikan penulisan',
      (tester) async {
    final issuedAt = DateTime.parse('2026-10-01T08:00:00Z');
    final lease = OfflineLease(
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(const Duration(hours: 24)),
      initialMonotonic: const Duration(seconds: 100),
    );

    // Within window: writable.
    expect(
      lease.canWrite(
        issuedAt.add(const Duration(hours: 5)),
        const Duration(seconds: 18100),
      ),
      true,
    );

    // Past 24h: locked.
    expect(
      lease.canWrite(
        issuedAt.add(const Duration(hours: 25)),
        const Duration(seconds: 90100),
      ),
      false,
    );

    // Wall clock rewound: locked.
    expect(
      lease.canWrite(
        issuedAt.subtract(const Duration(hours: 1)),
        const Duration(seconds: 18100),
      ),
      false,
    );
  });

  testWidgets('bootstrap tidak menghapus draft/outbox yang belum terkirim',
      (tester) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();
    s.transport.offline = true;
    await s.enqueueDaily();
    await s.enqueueIncident('Air minum keruh');

    expect(await s.pendingIds(), hasLength(2));

    // Bring the network back and run bootstrap: accepted snapshot is replaced,
    // but local drafts and outbox intents must survive (AC-34).
    s.transport.offline = false;
    await s.bootstrap.refresh();

    expect(await s.pendingIds(), hasLength(2));
    expect(await s.incidentText(), 'Air minum keruh');
    expect(await s.acceptedScopeIds(), contains('cage-1'));
  });
}
