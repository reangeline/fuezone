import 'package:flutter/material.dart';

abstract final class AppAnimations {
  static const durationFast   = Duration(milliseconds: 120);
  static const durationMedium = Duration(milliseconds: 250);
  static const durationSlow   = Duration(milliseconds: 400);

  static const curveDefault  = Curves.easeOutCubic;   // maioria dos elementos
  static const curveSpring   = Curves.elasticOut;      // bounce (PressableCard)
  static const curveEmphasis = Curves.easeInOutCubic; // transições de tela
  static const curveFade     = Curves.easeInOut;       // opacidade
}
