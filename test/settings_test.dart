import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jaiplay/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DJ mix is enabled by default and persists when disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();

    expect(settings.crossfadeEnabled, isTrue);

    await settings.setCrossfadeEnabled(false);
    expect(settings.crossfadeEnabled, isFalse);

    final restored = AppSettings();
    await restored.load();
    expect(restored.crossfadeEnabled, isFalse);
  });
}
