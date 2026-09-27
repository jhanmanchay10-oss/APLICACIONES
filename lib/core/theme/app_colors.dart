import 'package:flutter/material.dart';

import '../../models/traffic_light.dart';

abstract final class AppColors {
  static const green = Color(0xFF2E9E5B);
  static const orange = Color(0xFFF08C1A);
  static const red = Color(0xFFE0483E);

  static const leaf = Color(0xFF1F6B3F);
  static const cream = Color(0xFFF7F8F3);
  static const ink = Color(0xFF1C2620);
  static const mist = Color(0xFFE7ECE4);

  static Color forLight(TrafficLight light) => switch (light) {
        TrafficLight.green => green,
        TrafficLight.orange => orange,
        TrafficLight.red => red,
      };

  /// Fondo suave para tarjetas asociadas a un color del semáforo.
  static Color softFor(TrafficLight light, Brightness brightness) =>
      forLight(light).withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.12);
}
