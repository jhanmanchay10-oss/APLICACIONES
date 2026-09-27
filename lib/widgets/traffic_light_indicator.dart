import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/traffic_light.dart';

/// Semáforo visual con la luz activa encendida y las demás atenuadas.
class TrafficLightIndicator extends StatelessWidget {
  const TrafficLightIndicator({super.key, required this.light, this.lampSize = 34});

  final TrafficLight light;
  final double lampSize;

  @override
  Widget build(BuildContext context) {
    const order = [TrafficLight.red, TrafficLight.orange, TrafficLight.green];
    return Semantics(
      label: 'Semáforo: ${light.label}, ${light.headline}',
      child: Container(
        padding: EdgeInsets.all(lampSize * 0.22),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(lampSize),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in order)
              Padding(
                padding: EdgeInsets.symmetric(vertical: lampSize * 0.1),
                child: _Lamp(color: AppColors.forLight(item), active: item == light, size: lampSize),
              ),
          ],
        ),
      ),
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp({required this.color, required this.active, required this.size});

  final Color color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color : color.withValues(alpha: 0.18),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: size * 0.6)] : null,
        ),
      );
}

/// Etiqueta compacta con el color del semáforo.
class TrafficLightBadge extends StatelessWidget {
  const TrafficLightBadge({super.key, required this.light, this.compact = false});

  final TrafficLight light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLight(light);
    return Semantics(
      label: 'Semáforo ${light.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: AppColors.softFor(light, Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              light.label,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 11 : 13, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto de color para vistas compactas (resumen semanal).
class TrafficDot extends StatelessWidget {
  const TrafficDot({super.key, required this.light, this.size = 14});

  final TrafficLight? light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light == null ? Colors.transparent : AppColors.forLight(light!),
        border: light == null ? Border.all(color: scheme.outlineVariant, width: 2) : null,
      ),
    );
  }
}
