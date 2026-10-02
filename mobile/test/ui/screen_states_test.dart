// T42 — native whole-app state coverage (widget layer).
//
// Walks every (screen, state) pair declared in the design manifest and asserts
// the screen builds without throwing. This is the widget/unit half of the UAT;
// it does NOT replace the real-device checks (TalkBack, camera, OS storage
// faults) recorded in docs/evidence/android-uat.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/bootstrap_coordinator.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart';
import 'package:mobile/core/sync/retry_policy.dart';
import 'package:mobile/core/sync/sync_worker.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

import '../support/gallery.dart';

void main() {
  late List<Map<String, dynamic>> manifest;

  setUpAll(() {
    // The manifest is the single source of truth for the 24 screens / states.
    final file = File('../preview/manifest.json');
    final raw = file.readAsStringSync();
    manifest = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  });

  Future<ScreenGallery> makeGallery() async {
    final store = PartitionStore();
    await store.unlock(const PartitionId(
      actorId: ScreenGallery.operatorId,
      farmId: ScreenGallery.farmId,
    ));
    final cache = CacheRepository(store: store);
    final outbox = OutboxRepository(store: store);
    final transport = GalleryTransport();
    final worker = SyncWorker(
      outbox: outbox,
      transport: transport,
      retryPolicy: RetryPolicy(),
    );
    final coordinator = BootstrapCoordinator(
      cache: cache,
      outbox: outbox,
      transport: transport,
    );
    return ScreenGallery(
      store: store,
      cache: cache,
      outbox: outbox,
      transport: transport,
      worker: worker,
      coordinator: coordinator,
    );
  }

  test('manifest declares 24 screens and 132 states', () {
    expect(manifest, hasLength(24));
    final totalStates = manifest.fold<int>(
      0,
      (sum, s) => sum + (s['states'] as List<dynamic>).length,
    );
    expect(totalStates, 132);
  });

  testWidgets('every screen renders every declared state without throwing',
      (tester) async {
    final failures = <String>[];
    var checked = 0;

    for (final screen in manifest) {
      final id = screen['id'] as String;
      final states = (screen['states'] as List<dynamic>).cast<String>();
      for (final state in states) {
        final gallery = await makeGallery();
        // Seed cache-backed screens so "normal" states are meaningful.
        await gallery.seed('cage', [
          {'id': 'cage-1', 'code': 'K01', 'name': 'Kandang A'},
        ]);
        await gallery.seed('flock', [
          {
            'id': 'flock-1',
            'name': 'Kelompok A',
            'status': 'active',
            'start_date': '2026-09-01',
            'initial_population': 500,
          },
        ]);
        await gallery.seed('feed_balance', [
          {
            'feed_type_id': 'feed-1',
            'feed_type_name': 'Pakan Layer',
            'balance_kg': '120.00',
            'as_of': DateTime.now().toUtc().toIso8601String(),
          },
        ]);
        await gallery.seed('daily', [
          {
            'id': 'daily-1',
            'cage_id': 'cage-1',
            'business_date': '2026-10-01',
            'feed_kg': '12.50',
            'eggs_count': 85,
          },
        ]);
        await gallery.seed('incident', [
          {
            'id': 'incident-1',
            'cage_id': 'cage-1',
            'observation': 'Ada ayam lesu.',
            'attention': 'priority',
            'status': 'open',
            'assignee_id': null,
            'observed_at': '2026-10-02T06:00:00Z',
            'version': 1,
          },
        ]);
        await gallery.seed('task_run', [
          {
            'id': 'run-1',
            'title': 'Periksa pakan',
            'sop': 'Langkah 1',
            'status': 'open',
            'checklist_items': [
              {'id': 'item-1', 'label': 'Cek pakan'},
            ],
          },
        ]);

        try {
          await tester.pumpWidget(
            gallery.appAt(id, args: {'state': state}),
          );
          await tester.pump(const Duration(milliseconds: 50));
          // A loading state may never settle; a single pump is enough to
          // verify the frame builds. Non-loading states settle fully.
          if (galleryModeFor(state) != GalleryStateMode.loading) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          final ex = tester.takeException();
          if (ex != null) {
            failures.add('$id/$state: $ex');
          }
        } catch (e) {
          failures.add('$id/$state: $e');
        }
        checked += 1;
      }
    }

    expect(failures, isEmpty, reason: 'Gagal render: ${failures.join('; ')}');
    expect(checked, 132);
  });

  // AC-40 requires both 320dp and 414dp at 200% text scale.
  for (final width in const [320.0, 414.0]) {
    testWidgets('layout survives ${width.toInt()}dp width with 200% text scale',
        (tester) async {
      tester.view.physicalSize = Size(width * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final failures = <String>[];

      for (final screen in manifest) {
        final id = screen['id'] as String;
        final gallery = await makeGallery();
        await gallery.seed('cage', [
          {'id': 'cage-1', 'code': 'K01', 'name': 'Kandang A'},
        ]);
        await gallery.seed('feed_balance', [
          {
            'feed_type_id': 'feed-1',
            'feed_type_name': 'Pakan Layer',
            'balance_kg': '120.00',
            'as_of': DateTime.now().toUtc().toIso8601String(),
          },
        ]);

        try {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: gallery.appAt(id, args: {'state': 'default'}),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
          final ex = tester.takeException();
          if (ex != null) {
            failures.add('$id: $ex');
          }
        } catch (e) {
          failures.add('$id: $e');
        }
      }

      expect(failures, isEmpty,
          reason:
              'Overflow/exception pada ${width.toInt()}dp 200%: ${failures.join('; ')}');
    });
  }

  testWidgets('interactive targets meet the 48dp minimum', (tester) async {
    // AC-40: important actions must be at least 48dp. Material buttons expose
    // their real hit target as the *button widget's* render box (the theme
    // pins minimumSize to 48x48); the InkWell nested inside a button is only
    // the inner ink area and is not the target. So we check every button's
    // render box, plus any app-level InkWell/GestureDetector that is NOT
    // nested inside a button. We use render-box sizes (layout size) rather
    // than semantic rects so that off-screen list children are measured at
    // their full size instead of their clipped viewport slice.
    const buttonTypes = <Type>[
      IconButton,
      ElevatedButton,
      TextButton,
      FilledButton,
      OutlinedButton,
      FloatingActionButton,
    ];
    final offenders = <String>[];

    for (final screen in manifest) {
      final id = screen['id'] as String;
      final gallery = await makeGallery();
      await gallery.seed('cage', [
        {'id': 'cage-1', 'code': 'K01', 'name': 'Kandang A'},
      ]);
      await tester.pumpWidget(gallery.appAt(id, args: {'state': 'default'}));
      await tester.pump(const Duration(milliseconds: 50));

      final targets = find.byWidgetPredicate((w) =>
          buttonTypes.contains(w.runtimeType) ||
          w is InkWell ||
          w is GestureDetector);
      for (final el in targets.evaluate()) {
        // Skip inner ink / gesture detectors that live inside a Material
        // button: their padded button ancestor is the real 48dp target.
        var insideButton = false;
        el.visitAncestorElements((a) {
          if (buttonTypes.contains(a.widget.runtimeType)) {
            insideButton = true;
            return false;
          }
          return true;
        });
        if (insideButton) continue;

        final size = el.size;
        if (size == null) continue;
        if (size.width < 48 || size.height < 48) {
          offenders
              .add('$id: ${el.widget.runtimeType} ${size.width}x${size.height}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Target sentuh <48dp: ${offenders.join('; ')}');
  });

  testWidgets('reduced motion yields zero-duration theme animations',
      (tester) async {
    late Duration motion;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            motion = TernavaTheme.getMotionDuration(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(motion, Duration.zero);
  });
}
