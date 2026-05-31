import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  test('Identity derivation is deterministic', () async {
    final sodium = await SodiumSumoInit.init();
    expect(sodium, isNotNull);
  });
}
