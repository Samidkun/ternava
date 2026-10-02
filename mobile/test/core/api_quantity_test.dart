import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/quantity/kg.dart';

void main() {
  group('Kg quantity tests', () {
    test('kg memakai integer presisi', () {
      final kg = Kg.parse('12.50');
      expect(kg.units, BigInt.from(1250));
      expect(kg.wire(), '12.50');

      expect(() => Kg.parse(''), throwsFormatException);
      expect(() => Kg.parse('12.5'), throwsFormatException);
      expect(() => Kg.parse('12.500'), throwsFormatException);
      expect(() => Kg.parse('-12.50'), throwsFormatException);
      expect(() => Kg.parse('abc'), throwsFormatException);

      final fromUnits = Kg.fromUnits(BigInt.from(1250));
      expect(fromUnits.wire(), '12.50');
    });

    test('kg arithmetic addition and subtraction', () {
      final a = Kg.parse('10.25');
      final b = Kg.parse('5.50');

      final sum = a + b;
      expect(sum.wire(), '15.75');

      final diff = a - b;
      expect(diff.wire(), '4.75');
    });
  });

  group('ApiFailure tests', () {
    test('parses uniform error envelope properly', () {
      final failure = ApiFailure.fromJson({
        'error': {
          'code': 'INSUFFICIENT_STOCK',
          'message': 'Saldo pakan tidak mencukupi',
          'retryable': false,
        }
      }, 422);

      expect(failure.code, 'INSUFFICIENT_STOCK');
      expect(failure.status, 422);
      expect(failure.message, 'Saldo pakan tidak mencukupi');
      expect(failure.retryable, false);
      expect(failure.currentVersion, isNull);
    });

    test('parses version conflict with current version', () {
      final failure = ApiFailure.fromJson({
        'error': {
          'code': 'VERSION_CONFLICT',
          'message': 'Versi catatan telah berubah',
          'current_version': 2,
          'retryable': false,
        }
      }, 409);

      expect(failure.code, 'VERSION_CONFLICT');
      expect(failure.status, 409);
      expect(failure.currentVersion, 2);
    });
  });

  group('ApiClient tests with local mock server', () {
    late HttpServer server;
    late ApiClient client;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      client = ApiClient(baseUrl: 'http://${server.address.host}:${server.port}');
    });

    tearDown(() async {
      await server.close();
    });

    test('request injects auth token and idempotency key', () async {
      client.setAuthToken('token-abc-123');

      server.listen((HttpRequest request) {
        expect(request.headers.value('Authorization'), 'Bearer token-abc-123');
        expect(request.headers.value('Idempotency-Key'), 'key-uuid-999');
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/daily-records');

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'data': {'status': 'accepted', 'version': 1}
          }))
          ..close();
      });

      final res = await client.request(
        'createDaily',
        idempotencyKey: 'key-uuid-999',
        body: {'feed_kg': '15.00'},
      );

      expect(res['data'], isA<Map<String, dynamic>>());
      final data = res['data']! as Map<String, dynamic>;
      expect(data['status'], 'accepted');
    });

    test('throws structured ApiFailure on HTTP 422', () async {
      server.listen((HttpRequest request) {
        request.response
          ..statusCode = HttpStatus.unprocessableEntity
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'error': {
              'code': 'INSUFFICIENT_STOCK',
              'message': 'Saldo pakan habis',
              'retryable': false,
            }
          }))
          ..close();
      });

      expect(
        () => client.request('createDaily'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'INSUFFICIENT_STOCK')
            .having((e) => e.status, 'status', 422)),
      );
    });
  });
}
