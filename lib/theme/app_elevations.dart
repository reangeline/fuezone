import 'package:flutter/material.dart';

/// Elevation system: shadow profiles for visual hierarchy.
/// Used to create depth without borders.
abstract final class AppElevations {
  // Subtle shadow: hover states, minimal elevation
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Medium shadow: cards, buttons, active states
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 8,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // Prominent shadow: floating actions, modals, top-level surfaces
  static const List<BoxShadow> prominent = [
    BoxShadow(
      color: Color(0x3D000000),
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // No shadow: flat surfaces, backgrounds
  static const List<BoxShadow> none = [];
}
