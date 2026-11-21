import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Discrete text-size levels for the whole app. 1.0 is the default size.
enum TextScale {
  small(0.85, 'Small'),
  normal(1.0, 'Normal'),
  large(1.15, 'Large'),
  xLarge(1.3, 'Very large');

  const TextScale(this.factor, this.label);

  final double factor;
  final String label;
}

const _prefKey = 'strata_text_scale';

class TextScaleNotifier extends Notifier<TextScale> {
  @override
  TextScale build() => TextScale.normal;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefKey) ?? 1;
    state = TextScale.values[index.clamp(0, TextScale.values.length - 1)];
  }

  Future<void> set(TextScale scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, scale.index);
  }
}

final textScaleProvider = NotifierProvider<TextScaleNotifier, TextScale>(
  TextScaleNotifier.new,
);
