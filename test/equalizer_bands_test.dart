import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/equalizer_bands.dart';

void main() {
  test('exposes the nine requested frequency bands', () {
    expect(
      equalizerFrequenciesHz,
      [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
    );
  });

  test('resamples existing gain lists to nine controls', () {
    final gains = normalizeEqualizerGains([-6, 0, 6]);

    expect(gains, hasLength(9));
    expect(gains.first, -6);
    expect(gains[4], 0);
    expect(gains.last, 6);
  });

  test('interpolates gains by logarithmic frequency', () {
    final gains = List<double>.generate(9, (index) => index.toDouble());

    expect(equalizerGainAtFrequency(gains, 125), 1);
    expect(equalizerGainAtFrequency(gains, 16000), 8);
  });
}
