import 'dart:async';

import '../api/generated/types.dart';
import 'cache_repository.dart';
import 'outbox_repository.dart';

abstract class SyncTransport {
  Future<List<JsonObject>> fetchAllBootstrapPages();
}

class BootstrapCoordinator {
  final CacheRepository cache;
  final OutboxRepository outbox;
  final SyncTransport transport;

  BootstrapCoordinator({
    required this.cache,
    required this.outbox,
    required this.transport,
  });

  Future<void> refresh() async {
    // 1. Fetch complete bootstrap pages
    final pages = await transport.fetchAllBootstrapPages();

    // 2. Replace accepted cache atomically without touching outbox drafts!
    await cache.replaceAcceptedSnapshot(pages);

    // 3. Recover any stuck sending state in outbox
    await outbox.recoverSending();
  }
}
