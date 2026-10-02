import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'partition_store.dart';

class PartitionMismatch implements Exception {
  final String message;
  const PartitionMismatch(this.message);

  @override
  String toString() => 'PartitionMismatch: $message';
}

class PayloadCipher {
  final PartitionId partitionId;
  final SecretKey _secretKey;
  final AesGcm _algorithm = AesGcm.with256bits();

  PayloadCipher._({required this.partitionId, required this._secretKey});

  static Future<PayloadCipher> forPartition(PartitionId partitionId) async {
    final keyMaterial = sha256
        .convert(
          utf8.encode(
            'ternava.partition.${partitionId.farmId}.${partitionId.actorId}',
          ),
        )
        .bytes;
    final secretKey = SecretKey(keyMaterial);

    return PayloadCipher._(partitionId: partitionId, secretKey: secretKey);
  }

  Future<Uint8List> encrypt(Uint8List bytes, String aad) async {
    final nonce = _algorithm.newNonce();
    final fullAad = '${partitionId.farmId}:${partitionId.actorId}:$aad';
    final secretBox = await _algorithm.encrypt(
      bytes,
      secretKey: _secretKey,
      nonce: nonce,
      aad: utf8.encode(fullAad),
    );

    return Uint8List.fromList(secretBox.concatenation());
  }

  Future<Uint8List> decrypt(Uint8List concatenated, String aad) async {
    try {
      final secretBox = SecretBox.fromConcatenation(
        concatenated,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );

      final fullAad = '${partitionId.farmId}:${partitionId.actorId}:$aad';
      final decrypted = await _algorithm.decrypt(
        secretBox,
        secretKey: _secretKey,
        aad: utf8.encode(fullAad),
      );

      return Uint8List.fromList(decrypted);
    } catch (_) {
      throw const PartitionMismatch(
        'Gagal mendekripsi payload: partisi tidak cocok atau AAD salah.',
      );
    }
  }
}
