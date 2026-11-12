import 'dart:math' as math;

const equalizerFrequenciesHz = <double>[
  63,
  125,
  250,
  500,
  1000,
  2000,
  4000,
  8000,
  16000,
];

List<double> normalizeEqualizerGains(List<double> gains) {
  if (gains.length == equalizerFrequenciesHz.length) return List.of(gains);
  if (gains.isEmpty) return List.filled(equalizerFrequenciesHz.length, 0);
  if (gains.length == 1) {
    return List.filled(equalizerFrequenciesHz.length, gains.first);
  }

  return List<double>.generate(equalizerFrequenciesHz.length, (index) {
    final position =
        index * (gains.length - 1) / (equalizerFrequenciesHz.length - 1);
    final low = position.floor();
    final high = (low + 1).clamp(0, gains.length - 1);
    final fraction = position - low;
    return gains[low] * (1 - fraction) + gains[high] * fraction;
  });
}

double equalizerGainAtFrequency(List<double> gains, double frequencyHz) {
  final normalized = normalizeEqualizerGains(gains);
  if (frequencyHz <= equalizerFrequenciesHz.first) return normalized.first;
  if (frequencyHz >= equalizerFrequenciesHz.last) return normalized.last;

  for (var index = 0; index < equalizerFrequenciesHz.length - 1; index++) {
    final lowerFrequency = equalizerFrequenciesHz[index];
    final upperFrequency = equalizerFrequenciesHz[index + 1];
    if (frequencyHz > upperFrequency) continue;

    final position = math.log(frequencyHz / lowerFrequency) /
        math.log(upperFrequency / lowerFrequency);
    return normalized[index] * (1 - position) +
        normalized[index + 1] * position;
  }

  return normalized.last;
}

List<double> equalizerPresetGains(String preset) => switch (preset) {
      'Pop' => const [0.0, 1.0, 2.0, 3.0, 2.0, 1.0, 0.0, 0.0, 0.0],
      'Rock' => const [4.0, 4.0, 2.0, 0.0, -1.0, 1.0, 3.0, 4.0, 4.0],
      'Jazz' => const [2.0, 2.0, 1.0, 0.0, 0.0, 2.0, 3.0, 3.0, 3.0],
      'Clásica' => const [0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 3.0, 3.0, 3.0],
      'Electrónica' => const [4.0, 4.0, 2.0, 0.0, 0.0, 2.0, 3.0, 4.0, 4.0],
      'Voz' => const [-3.0, -2.0, 0.0, 2.0, 3.0, 3.0, 2.0, 0.0, -2.0],
      'Aumento de graves' || 'Bass boost' => const [
          6.0,
          6.0,
          5.0,
          3.0,
          2.0,
          1.0,
          0.0,
          0.0,
          0.0
        ],
      'Aumento de voz' || 'Podcast' => const [
          -3.0,
          -2.0,
          -1.0,
          1.0,
          3.0,
          4.0,
          4.0,
          2.0,
          1.0
        ],
      'Balanced' || 'Plano' || 'Desactivado' || 'Manual' || 'Custom' => const [
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0
        ],
      'Smooth' => const [2.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, 2.0, 2.0],
      'Dynamic' => const [4.0, 3.0, 2.0, 0.0, 1.0, 2.0, 3.0, 2.0, 1.0],
      'Clear' => const [-1.0, 0.0, 1.0, 2.0, 3.0, 3.0, 2.0, 2.0, 1.0],
      'Treble boost' => const [-1.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 5.0],
      _ => const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    };
