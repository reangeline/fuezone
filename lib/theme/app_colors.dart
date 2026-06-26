import 'package:flutter/material.dart';

import '../timer/timer_models.dart';

abstract final class AppColors {
  // Neutros — modo escuro (dominante)
  static const background   = Color(0xFF0D0D0F);
  static const surface      = Color(0xFF1A1A1F);
  static const surfaceHigh  = Color(0xFF26262E);
  static const onBackground = Color(0xFFF2F2F5);
  static const onSurface    = Color(0xFFB8B8C8);

  // Primária — vermelho vibrante (trabalho, energia)
  static const primary      = Color(0xFFFF3B30);
  static const primaryLight = Color(0xFFFF6B5B);
  static const onPrimary    = Color(0xFFFFFFFF);

  // Cores por fase
  static const work     = Color(0xFFFF3B30); // vermelho  — trabalho/luta
  static const rest     = Color(0xFF0A84FF); // azul      — descanso
  static const prepare  = Color(0xFF30D158); // verde     — prepare
  static const cooldown = Color(0xFF5E5CE6); // índigo    — cooldown

  // Alerta/aviso
  static const warning = Color(0xFFFF9F0A);

  // Modo claro
  static const backgroundLight  = Color(0xFFF5F5F7);
  static const surfaceLight      = Color(0xFFFFFFFF);
  static const onBackgroundLight = Color(0xFF0D0D0F);

  // Opacidades — para efeitos de vidro, texto hint, etc.
  static const alpha08 = 0.08;
  static const alpha15 = 0.15;
  static const alpha30 = 0.30;
  static const alpha60 = 0.60;

  static Color forPhase(PhaseType type) => switch (type) {
        PhaseType.work     => work,
        PhaseType.rest     => rest,
        PhaseType.prepare  => prepare,
        PhaseType.cooldown => cooldown,
      };
}
