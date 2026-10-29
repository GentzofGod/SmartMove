import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/services/guide_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuideService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. hasSeenGuide returns false initially for new users', () async {
      final hasSeen = await GuideService.hasSeenGuide();
      expect(hasSeen, isFalse);
    });

    test('2. markGuideSeen updates storage so hasSeenGuide returns true', () async {
      await GuideService.markGuideSeen();
      final hasSeen = await GuideService.hasSeenGuide();
      expect(hasSeen, isTrue);
    });

    test('3. resetGuide removes stored flag so hasSeenGuide returns false again', () async {
      await GuideService.markGuideSeen();
      expect(await GuideService.hasSeenGuide(), isTrue);

      await GuideService.resetGuide();
      expect(await GuideService.hasSeenGuide(), isFalse);
    });
  });
}
