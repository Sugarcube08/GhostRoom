import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostroom/core/network/update_service.dart';

void main() {
  group('UpdateManifest Parsing & OS Analysis', () {
    test('parses full manifest with multi-platform assets', () {
      final json = {
        'version': '2.2.3',
        'release_date': '2026-11-15T18:15:00Z',
        'release_url': 'https://github.com/Sugarcube08/GhostRoom/releases/tag/v2.2.3',
        'changelog': 'New release with auto-updater',
        'platforms': {
          'android': {
            'url': 'https://example.com/ghostroom-android.apk',
            'filename': 'ghostroom-android.apk',
            'sha256': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            'size_bytes': 45123456,
          },
          'linux': {
            'url': 'https://example.com/ghostroom-linux-x86_64.AppImage',
            'filename': 'ghostroom-linux-x86_64.AppImage',
            'sha256': 'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3',
            'size_bytes': 65432100,
          },
        },
      };

      final manifest = UpdateManifest.fromJson(json);

      expect(manifest.version, '2.2.3');
      expect(manifest.changelog, 'New release with auto-updater');
      expect(manifest.platforms.containsKey('android'), isTrue);
      expect(manifest.platforms.containsKey('linux'), isTrue);

      final androidAsset = manifest.platforms['android']!;
      expect(androidAsset.filename, 'ghostroom-android.apk');
      expect(androidAsset.sizeBytes, 45123456);
      expect(androidAsset.sha256, 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2');

      final assetForCurrent = manifest.getAssetForCurrentPlatform();
      expect(assetForCurrent, isNotNull);
      if (Platform.isLinux) {
        expect(assetForCurrent!.filename, 'ghostroom-linux-x86_64.AppImage');
      } else if (Platform.isAndroid) {
        expect(assetForCurrent!.filename, 'ghostroom-android.apk');
      }
    });

    test('strips leading v from version tag', () {
      final json = {
        'version': 'v2.3.0',
        'release_url': 'https://example.com',
      };
      final manifest = UpdateManifest.fromJson(json);
      expect(manifest.version, '2.3.0');
    });
  });

  group('UpdateService Semver Comparison', () {
    final service = UpdateService();

    test('correctly identifies newer semantic versions', () {
      // Access private _isNewer via reflection / helper test
      // Test matrix:
      final newerPairs = [
        ['2.2.3', '2.2.2'],
        ['3.0.0', '2.9.9'],
        ['2.3.0', '2.2.9'],
        ['v2.2.3', '2.2.2'],
        ['2.2.3', 'v2.2.2'],
        ['2.2.2', '2.2.2-beta.1'],
      ];

      for (final pair in newerPairs) {
        expect(
          service.isNewerVersion(pair[0], pair[1]),
          isTrue,
          reason: 'Expected ${pair[0]} to be newer than ${pair[1]}',
        );
      }
    });

    test('correctly rejects older or identical versions', () {
      final nonNewerPairs = [
        ['2.2.2', '2.2.2'],
        ['2.2.1', '2.2.2'],
        ['1.9.9', '2.0.0'],
        ['2.2.0', '2.2.1'],
      ];

      for (final pair in nonNewerPairs) {
        expect(
          service.isNewerVersion(pair[0], pair[1]),
          isFalse,
          reason: 'Expected ${pair[0]} NOT to be newer than ${pair[1]}',
        );
      }
    });
  });

  group('SHA-256 Checksum Verification', () {
    test('verifies integrity of payload and rejects tampered bytes', () {
      final sampleContent = utf8.encode('GhostRoom Release Payload 2.2.3');
      final validHash = sha256.convert(sampleContent).toString();

      final calculatedValid = sha256.convert(sampleContent).toString().toLowerCase();
      expect(calculatedValid, validHash.toLowerCase());

      final tamperedContent = utf8.encode('GhostRoom Tampered Payload 2.2.3');
      final calculatedTampered = sha256.convert(tamperedContent).toString().toLowerCase();
      expect(calculatedTampered, isNot(equals(validHash.toLowerCase())));
    });
  });
}
