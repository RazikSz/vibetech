import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/pages/home/profile_page.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'isDarkMode': false});
    await ThemeService.initTheme();
  });

  testWidgets('ProfilePage sinkron dengan ThemeService (Light Mode ke Dark Mode)', (tester) async {
    // Pastikan awal adalah Light Mode
    expect(ThemeService.isDarkMode, false);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          isDarkMode: ThemeService.isDarkMode,
          username: 'tester',
        ),
      ),
    );
    await tester.pump();

    // Toggle tema melalui ThemeService (seperti yang dilakukan tombol AppBar dan switch pengaturan)
    await ThemeService.toggleTheme();
    await tester.pump();

    expect(ThemeService.isDarkMode, true);

    // Toggle kembali ke Light Mode
    await ThemeService.toggleTheme();
    await tester.pump();

    expect(ThemeService.isDarkMode, false);
  });
}
