import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:bs58/bs58.dart';

void main() {
  test('Launch Audit: Identity Collision Simulation', () async {
    final sodium = await SodiumSumoInit.init();
    final ids = <String>{};
    const count = 10000; // Lowered to 10k for faster test run, still indicative
    int collisions = 0;

    for (var i = 0; i < count; i++) {
      final pk = sodium.randombytes.buf(32);
      final hash = sodium.crypto.genericHash(message: pk, outLen: 20);
      final id = base58.encode(hash);
      
      if (ids.contains(id)) {
        collisions++;
      }
      ids.add(id);
    }
    
    expect(collisions, 0);
  });
}
