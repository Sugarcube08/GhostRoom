import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Deep Link & Universal Contact Route Parser', () {
    String? extractPublicIdFromUri(Uri uri) {
      if (uri.scheme == 'ghostroom') {
        if (uri.host == 'connect') {
          if (uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
        } else if (uri.pathSegments.contains('connect')) {
          final idx = uri.pathSegments.indexOf('connect');
          if (idx + 1 < uri.pathSegments.length) return uri.pathSegments[idx + 1];
        } else if (uri.pathSegments.contains('u')) {
          final idx = uri.pathSegments.indexOf('u');
          if (idx + 1 < uri.pathSegments.length) return uri.pathSegments[idx + 1];
        } else if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
      }

      if (uri.scheme == 'https' || uri.scheme == 'http') {
        if (uri.pathSegments.isNotEmpty) {
          final first = uri.pathSegments.first;
          if ((first == 'connect' || first == 'u') && uri.pathSegments.length > 1) {
            return uri.pathSegments[1];
          }
        }
        if (uri.queryParameters.containsKey('id')) {
          return uri.queryParameters['id'];
        }
      }

      return null;
    }

    test('parses custom scheme ghostroom://connect/<publicId>', () {
      final uri = Uri.parse('ghostroom://connect/8FkLq2mQzV7Y');
      expect(extractPublicIdFromUri(uri), '8FkLq2mQzV7Y');
    });

    test('parses universal https app link /connect/<publicId>', () {
      final uri = Uri.parse('https://ghost-room-chi.vercel.app/connect/8FkLq2mQzV7Y');
      expect(extractPublicIdFromUri(uri), '8FkLq2mQzV7Y');
    });

    test('parses short universal link /u/<publicId>', () {
      final uri = Uri.parse('https://ghost-room-chi.vercel.app/u/5NxPq8vR1mA');
      expect(extractPublicIdFromUri(uri), '5NxPq8vR1mA');
    });

    test('parses invite query parameter ?ref=invite&id=<publicId>', () {
      final uri = Uri.parse('https://ghost-room-chi.vercel.app/?ref=invite&id=K9jLm3nP8qR');
      expect(extractPublicIdFromUri(uri), 'K9jLm3nP8qR');
    });

    test('rejects unformatted or unrelated paths', () {
      final uri = Uri.parse('https://ghost-room-chi.vercel.app/download');
      expect(extractPublicIdFromUri(uri), isNull);
    });
  });
}
