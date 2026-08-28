import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService Tests', () {
    test('ThemeService default toggle and persistent state', () async {
      await ThemeService.setTheme(true);
      expect(ThemeService.isDarkMode, true);
      expect(ThemeService.themeNotifier.value, true);

      await ThemeService.toggleTheme();
      expect(ThemeService.isDarkMode, false);
      expect(ThemeService.themeNotifier.value, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), false);

      // Re-init from prefs
      await ThemeService.initTheme();
      expect(ThemeService.isDarkMode, false);

      // Toggle back to dark
      await ThemeService.toggleTheme();
      expect(ThemeService.isDarkMode, true);
      expect(prefs.getBool('isDarkMode'), true);
    });

    test('ThemeService notifies listeners when theme changes', () async {
      bool? notifiedTheme;
      void listener() {
        notifiedTheme = ThemeService.themeNotifier.value;
      }

      ThemeService.themeNotifier.addListener(listener);

      await ThemeService.setTheme(false);
      expect(notifiedTheme, false);

      await ThemeService.setTheme(true);
      expect(notifiedTheme, true);

      ThemeService.themeNotifier.removeListener(listener);
    });
  });
}
