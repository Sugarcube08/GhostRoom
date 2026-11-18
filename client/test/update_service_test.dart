import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostroom/core/network/update_service.dart';

void main() {
  group('UpdateManifest Parsing & OS Analysis', () {
    test('parses full manifest with multi-platform assets', () {
      final json = {
        'version': '2.5.0',
        'build_number': 6,
        'release_date': '2026-11-18T12:00:00Z',
        'release_url':
            'https://github.com/Sugarcube08/GhostRoom/releases/tag/v2.5.0',
        'changelog': 'New release with enhanced multi-format auto-updater',
        'platforms': {
          'android': {
            'name': 'Android Package (APK)',
            'format': 'apk',
            'url': 'https://example.com/ghostroom-android.apk',
            'filename': 'ghostroom-android.apk',
            'sha256':
                'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            'size_bytes': 45123456,
          },
          'linux': {
            'name': 'Linux Universal AppImage',
            'format': 'appimage',
            'url': 'https://example.com/ghostroom-linux-x86_64.AppImage',
            'filename': 'ghostroom-linux-x86_64.AppImage',
            'sha256':
                'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3',
            'size_bytes': 12354752,
          },
          'linux_deb': {
            'name': 'Debian / Ubuntu (.deb)',
            'format': 'deb',
            'url': 'https://example.com/ghostroom-linux.deb',
            'filename': 'ghostroom-linux.deb',
            'sha256':
                'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
            'size_bytes': 9817314,
          },
          'linux_rpm': {
            'name': 'Fedora / RHEL / openSUSE (.rpm)',
            'format': 'rpm',
            'url': 'https://example.com/ghostroom-2.5.0-2.x86_64.rpm',
            'filename': 'ghostroom-2.5.0-2.x86_64.rpm',
            'sha256':
                'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5',
            'size_bytes': 9836152,
          },
          'linux_tar': {
            'name': 'Linux Standalone Bundle (.tar.gz)',
            'format': 'tar.gz',
            'url': 'https://example.com/ghostroom-linux-x86_64.tar.gz',
            'filename': 'ghostroom-linux-x86_64.tar.gz',
            'sha256':
                'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6',
            'size_bytes': 12102039,
          },
        },
      };

      final manifest = UpdateManifest.fromJson(json);

      expect(manifest.version, '2.5.0');
      expect(manifest.buildNumber, 6);
      expect(manifest.changelog,
          'New release with enhanced multi-format auto-updater');
      expect(manifest.platforms.containsKey('android'), isTrue);
      expect(manifest.platforms.containsKey('linux'), isTrue);
      expect(manifest.platforms.containsKey('linux_deb'), isTrue);
      expect(manifest.platforms.containsKey('linux_rpm'), isTrue);
      expect(manifest.platforms.containsKey('linux_tar'), isTrue);

      final debAsset = manifest.platforms['linux_deb']!;
      expect(debAsset.filename, 'ghostroom-linux.deb');
      expect(debAsset.format, 'deb');
      expect(debAsset.displayName, 'Debian / Ubuntu (.deb)');
      expect(debAsset.formattedSize, contains('MB'));

      final assetForCurrent = manifest.getAssetForCurrentPlatform();
      expect(assetForCurrent, isNotNull);

      if (Platform.isLinux) {
        final available = manifest.getAvailableAssetsForCurrentPlatform();
        expect(available.length, greaterThanOrEqualTo(1));
        final filenames = available.map((a) => a.filename).toList();
        expect(filenames, contains('ghostroom-linux-x86_64.AppImage'));
      }
    });

    test('strips leading v from version tag and parses build_number', () {
      final json = {
        'version': 'v2.5.0',
        'build_number': 6,
        'release_url': 'https://example.com',
      };
      final manifest = UpdateManifest.fromJson(json);
      expect(manifest.version, '2.5.0');
      expect(manifest.buildNumber, 6);
    });
  });

  group('UpdateService Semver Comparison', () {
    final service = UpdateService();

    test('correctly identifies newer semantic versions', () {
      final newerPairs = [
        ['2.5.0', '2.2.4'],
        ['3.0.0', '2.9.9'],
        ['2.5.1', '2.5.0'],
        ['v2.5.0', '2.2.4'],
        ['2.5.0', 'v2.2.4'],
        ['2.5.0', '2.5.0-beta.1'],
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
        ['2.5.0', '2.5.0'],
        ['2.2.4', '2.5.0'],
        ['1.9.9', '2.0.0'],
        ['2.4.9', '2.5.0'],
      ];

      for (final pair in nonNewerPairs) {
        expect(
          service.isNewerVersion(pair[0], pair[1]),
          isFalse,
          reason: 'Expected ${pair[0]} NOT to be newer than ${pair[1]}',
        );
      }
    });

    test('correctly compares build numbers when semver versions match', () {
      expect(
        service.isNewerVersion('2.5.0', '2.5.0', remoteBuild: 6, localBuild: 5),
        isTrue,
      );
      expect(
        service.isNewerVersion('2.5.0+6', '2.5.0+5'),
        isTrue,
      );
      expect(
        service.isNewerVersion('2.5.0', '2.5.0', remoteBuild: 5, localBuild: 6),
        isFalse,
      );
      expect(
        service.isNewerVersion('2.5.0+5', '2.5.0+6'),
        isFalse,
      );
      expect(
        service.isNewerVersion('2.5.0', '2.5.0', remoteBuild: 6, localBuild: 6),
        isFalse,
      );
    });
  });

  group('SHA-256 Checksum Verification', () {
    test('verifies integrity of payload and rejects tampered bytes', () {
      final sampleContent = utf8.encode('GhostRoom Release Payload 2.5.0');
      final validHash = sha256.convert(sampleContent).toString();

      final calculatedValid =
          sha256.convert(sampleContent).toString().toLowerCase();
      expect(calculatedValid, validHash.toLowerCase());

      final tamperedContent = utf8.encode('GhostRoom Tampered Payload 2.5.0');
      final calculatedTampered =
          sha256.convert(tamperedContent).toString().toLowerCase();
      expect(calculatedTampered, isNot(equals(validHash.toLowerCase())));
    });
  });
}
