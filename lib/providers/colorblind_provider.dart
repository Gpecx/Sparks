import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ColorblindMode {
  none,
  protanopia,
  deuteranopia,
  tritanopia,
}

class ColorblindNotifier extends Notifier<ColorblindMode> {
  @override
  ColorblindMode build() => ColorblindMode.none;

  void setMode(ColorblindMode mode) {
    state = mode;
  }
}

final colorblindProvider = NotifierProvider<ColorblindNotifier, ColorblindMode>(() {
  return ColorblindNotifier();
});
