// Scenario fixture helper for mobile integration tests (T03)

import 'dart:async';

typedef JsonObject = Map<String, Object?>;

class MobileScenario {
  final Map<String, dynamic> state;
  final String farmId;
  final String operatorId;

  MobileScenario({
    required this.farmId,
    required this.operatorId,
    Map<String, dynamic>? initialData,
  }) : state = initialData ?? <String, dynamic>{};

  Future<void> relaunch() async {
    // Simulates app process restart
  }

  Future<void> loginAsOperator() async {
    state['authenticated_role'] = 'operator';
    state['authenticated_user_id'] = operatorId;
  }

  Future<void> loginAsOwner() async {
    state['authenticated_role'] = 'owner';
  }

  Future<List<String>> pendingIds() async {
    return (state['pending_intents'] as List<String>?) ?? <String>[];
  }
}

Future<MobileScenario> makeMobileScenario() async {
  return MobileScenario(
    farmId: 'farm-test-01',
    operatorId: 'operator-budi',
    initialData: {
      'cages_count': 2,
      'flocks_count': 2,
      'feed_stock_kg': '300.00',
    },
  );
}
