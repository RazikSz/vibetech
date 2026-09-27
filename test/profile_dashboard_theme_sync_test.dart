import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'isDarkMode': false});
    await ThemeService.initTheme();
  });

  testWidgets('ThemeService toggle synchronizes reactive listeners properly', (tester) async {
    expect(ThemeService.isDarkMode, false);

    bool isDarkState = ThemeService.isDarkMode;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: ThemeService.themeNotifier,
          builder: (context, isDark, child) {
            isDarkState = isDark;
            return Scaffold(
              backgroundColor: isDark ? Colors.black : Colors.white,
              body: Text(isDark ? 'Dark Mode' : 'Light Mode'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(isDarkState, false);
    expect(find.text('Light Mode'), findsOneWidget);

    // Toggle ke Dark Mode
    await ThemeService.toggleTheme();
    await tester.pump();
    expect(ThemeService.isDarkMode, true);
    expect(isDarkState, true);
    expect(find.text('Dark Mode'), findsOneWidget);

    // Toggle kembali ke Light Mode
    await ThemeService.toggleTheme();
    await tester.pump();
    expect(ThemeService.isDarkMode, false);
    expect(isDarkState, false);
    expect(find.text('Light Mode'), findsOneWidget);
  });
}
