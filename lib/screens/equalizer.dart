import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services.dart';
import '../settings.dart' as preferences;
import '../theme.dart';
import '../widgets.dart';
import '../equalizer_bands.dart';

const _legacyPresets = [
  'Desactivado',
  'Plano',
  'Pop',
  'Rock',
  'Jazz',
  'Clásica',
  'Electrónica',
  'Voz',
  'Aumento de graves',
  'Aumento de voz',
  'Podcast',
];

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  double _amplifierGain = preferences.appSettings.amplifierGainDb;
  final Map<int, double> _draftGains = {};

  Future<void> _savePreset(String value) async {
    try {
      await preferences.appSettings.setEqualizerPreset(value);
      if (mounted) {
        setState(_draftGains.clear);
      }
      if (player.current != null) {
        await player.applyEqualizerSettings(preset: value);
      }
    } catch (error) {
      _showError('No se pudo aplicar el perfil: $error');
    }
  }

  Future<void> _saveBandGains() async {
    final preset = preferences.appSettings.equalizerPreset;
    final baseGains = normalizeEqualizerGains(
      preset == 'Manual'
          ? preferences.appSettings.manualEqualizerGains
          : equalizerPresetGains(preset),
    );
    final gains = List<double>.generate(
      equalizerFrequenciesHz.length,
      (index) => _draftGains[index] ?? baseGains[index],
    );
    try {
      await preferences.appSettings.setEqualizerPreset('Manual');
      await preferences.appSettings.setManualEqualizerGains(gains);
      if (mounted) setState(() {});
      await player.applyEqualizerSettings(
        preset: 'Manual',
        manualGains: gains,
      );
    } catch (error) {
      _showError('No se pudieron guardar las bandas: $error');
    }
  }

  Future<void> _saveAmplifier(double value) async {
    try {
      await player.setAmplifierGain(value);
    } catch (error) {
      _showError('No se pudo aplicar el amplificador: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Ecualizador'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text('Ecualizador por frecuencias', style: kH2),
            const SizedBox(height: 8),
            if (!isAndroid)
              const Text(
                'El ecualizador está disponible en Android.',
                style: TextStyle(color: kMuted),
              )
            else
              ListenableBuilder(
                listenable: player,
                builder: (context, _) {
                  if (player.current == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Reproduce una canción para mostrar las bandas de frecuencia.',
                        style: TextStyle(color: kMuted),
                      ),
                    );
                  }
                  return FutureBuilder<AndroidEqualizerParameters>(
                    future: player.equalizer.parameters,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No se pudo iniciar el ecualizador: ${snapshot.error}',
                            style: const TextStyle(color: kAccent),
                          ),
                        );
                      }
                      final parameters = snapshot.data;
                      if (parameters == null) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final currentGains = normalizeEqualizerGains(
                        preferences.appSettings.equalizerPreset == 'Manual'
                            ? preferences.appSettings.manualEqualizerGains
                            : equalizerPresetGains(
                                preferences.appSettings.equalizerPreset,
                              ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF171719),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                            child: SizedBox(
                              height: 300,
                              child: Row(
                                children: [
                                  for (var index = 0;
                                      index < equalizerFrequenciesHz.length;
                                      index++)
                                    Expanded(
                                      child: _FrequencySlider(
                                        frequencyHz:
                                            equalizerFrequenciesHz[index],
                                        minimum: parameters.minDecibels,
                                        maximum: parameters.maxDecibels,
                                        value: _draftGains[index] ??
                                            currentGains[index],
                                        onChanged: (value) {
                                          setState(
                                              () => _draftGains[index] = value);
                                        },
                                        onChangeEnd: (_) => _saveBandGains(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              'Las frecuencias se adaptan a las bandas que admite este dispositivo.',
                              style: TextStyle(color: kMuted, fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _EqualizerPresets(
                            selectedPreset:
                                preferences.appSettings.equalizerPreset,
                            onSelected: _savePreset,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            if (isAndroid)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Más preajustes'),
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(preferences.appSettings.equalizerPreset),
                    initialValue: _legacyPresets
                            .contains(preferences.appSettings.equalizerPreset)
                        ? preferences.appSettings.equalizerPreset
                        : 'Plano',
                    decoration: const InputDecoration(
                      labelText: 'Perfil de sonido',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final preset in _legacyPresets)
                        DropdownMenuItem(value: preset, child: Text(preset)),
                    ],
                    onChanged: (value) {
                      if (value != null) _savePreset(value);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 28),
            const Text('Amplificador de volumen', style: kH2),
            const SizedBox(height: 4),
            Text(
              '${_amplifierGain.toStringAsFixed(0)} dB',
              style: const TextStyle(color: kMuted),
            ),
            Slider(
              value: _amplifierGain,
              min: 0,
              max: 12,
              divisions: 24,
              label: '${_amplifierGain.toStringAsFixed(1)} dB',
              onChanged: isAndroid
                  ? (value) => setState(() => _amplifierGain = value)
                  : null,
              onChangeEnd: isAndroid ? _saveAmplifier : null,
            ),
            const Text(
              'El volumen general se controla con los botones del teléfono. '
              'La amplificación puede aumentar la distorsión; súbela poco a poco.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _FrequencySlider extends StatelessWidget {
  final double frequencyHz;
  final double minimum;
  final double maximum;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _FrequencySlider({
    required this.frequencyHz,
    required this.minimum,
    required this.maximum,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final frequency = frequencyHz >= 1000
        ? '${(frequencyHz / 1000).toStringAsFixed(0)}k'
        : frequencyHz.round().toString();
    return Column(
      children: [
        Text(value.toStringAsFixed(0),
            style: const TextStyle(color: kMuted, fontSize: 12)),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 205,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: const Color(0xFF3478F6),
                  thumbColor: const Color(0xFF3478F6),
                  inactiveTrackColor: Colors.white24,
                  overlayColor: const Color(0x223478F6),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: value.clamp(minimum, maximum).toDouble(),
                  min: minimum,
                  max: maximum,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
          ),
        ),
        Text(frequency, style: const TextStyle(color: kMuted, fontSize: 10)),
      ],
    );
  }
}

class _EqualizerPresets extends StatelessWidget {
  final String selectedPreset;
  final ValueChanged<String> onSelected;

  const _EqualizerPresets({
    required this.selectedPreset,
    required this.onSelected,
  });

  static const _presets = [
    'Balanced',
    'Bass boost',
    'Smooth',
    'Dynamic',
    'Clear',
    'Treble boost',
    'Custom',
  ];

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.45,
        children: [
          for (final preset in _presets)
            FilledButton(
              onPressed: () =>
                  onSelected(preset == 'Custom' ? 'Manual' : preset),
              style: FilledButton.styleFrom(
                backgroundColor: selectedPreset == preset ||
                        (preset == 'Custom' && selectedPreset == 'Manual')
                    ? const Color(0xFF3478F6)
                    : const Color(0xFF29292B),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: Text(preset, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      );
}
