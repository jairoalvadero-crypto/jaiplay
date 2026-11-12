import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettings = AppSettings();

class AppSettings extends ChangeNotifier {
  late SharedPreferences _preferences;

  bool wifiOnly = true;
  bool crossfadeEnabled = false;
  double amplifierGainDb = 0;
  String equalizerPreset = 'Plano';
  String displayName = '';
  List<double> manualEqualizerGains = [];

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    wifiOnly = _preferences.getBool('settings_wifi_only') ?? true;
    crossfadeEnabled =
        _preferences.getBool('settings_crossfade_enabled') ?? true;
    amplifierGainDb =
        (_preferences.getDouble('settings_amplifier_gain_db') ?? 0)
            .clamp(0.0, 12.0);
    equalizerPreset = _preferences.getString('settings_eq_preset') ?? 'Plano';
    displayName = _preferences.getString('settings_display_name') ?? '';
    manualEqualizerGains =
        (_preferences.getStringList('settings_eq_gains') ?? const [])
            .map((gain) => double.tryParse(gain) ?? 0)
            .toList();
  }

  Future<void> setWifiOnly(bool value) async {
    await _saveBool('settings_wifi_only', value);
    wifiOnly = value;
    notifyListeners();
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    if (!await _preferences.setBool('settings_crossfade_enabled', value)) {
      throw StateError('No se pudo guardar el crossfade.');
    }
    crossfadeEnabled = value;
    notifyListeners();
  }

  Future<void> setAmplifierGain(double value) async {
    if (!value.isFinite || value < 0 || value > 12) {
      throw ArgumentError('La amplificación debe estar entre 0 y 12 dB.');
    }
    await _saveDouble('settings_amplifier_gain_db', value);
    amplifierGainDb = value;
    notifyListeners();
  }

  Future<void> setEqualizerPreset(String value) async {
    await _saveString('settings_eq_preset', value);
    equalizerPreset = value;
    notifyListeners();
  }

  Future<void> setDisplayName(String value) async {
    final name = value.trim();
    if (!await _preferences.setString('settings_display_name', name)) {
      throw StateError('No se pudo guardar el nombre.');
    }
    displayName = name;
    notifyListeners();
  }

  Future<void> setManualEqualizerGains(List<double> gains) async {
    final values = gains.map((gain) => gain.toString()).toList();
    final saved = await _preferences.setStringList('settings_eq_gains', values);
    if (!saved) throw StateError('No se pudo guardar el ecualizador.');
    manualEqualizerGains = List.of(gains);
    notifyListeners();
  }

  Future<void> _saveBool(String key, bool value) async {
    if (!await _preferences.setBool(key, value)) {
      throw StateError('No se pudo guardar la preferencia.');
    }
  }

  Future<void> _saveDouble(String key, double value) async {
    if (!await _preferences.setDouble(key, value)) {
      throw StateError('No se pudo guardar el valor del ajuste.');
    }
  }

  Future<void> _saveString(String key, String value) async {
    if (!await _preferences.setString(key, value)) {
      throw StateError('No se pudo guardar el perfil de sonido.');
    }
  }
}
