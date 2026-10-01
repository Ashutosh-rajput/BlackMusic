import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('a higher release tag is newer', () {
      expect(UpdateService.isNewerVersion('v1.7.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
    });
    test('compares numbers, not text: 1.10.0 is newer than 1.9.0', () {
      expect(UpdateService.isNewerVersion('v1.10.0', '1.9.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.9.0', '1.10.0'), isFalse);
    });
    test('same or older version is not an update', () {
      expect(UpdateService.isNewerVersion('v1.7.0', '1.7.0'), isFalse);
      expect(UpdateService.isNewerVersion('v1.6.9', '1.7.0'), isFalse);
    });
    test('build numbers and missing parts are handled', () {
      expect(UpdateService.isNewerVersion('v1.7', '1.7.0'), isFalse);
      expect(UpdateService.isNewerVersion('v2', '1.9.9+4'), isTrue);
      expect(UpdateService.isNewerVersion('v1.7.0', '1.7.0+12'), isFalse);
    });
    test('unparseable tags never trigger a popup', () {
      expect(UpdateService.isNewerVersion('latest', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v1.7.0', 'dev'), isFalse);
    });
  });
}
