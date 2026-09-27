import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Logo: un plato visto desde arriba con un semáforo en el centro y una hoja.
class NutriLogo extends StatelessWidget {
  const NutriLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Logo de NutriSemáforo',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: const _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * 0.47, s * 0.53);
    final plateRadius = s * 0.42;

    // Plato.
    canvas.drawCircle(center, plateRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      plateRadius,
      Paint()
        ..color = AppColors.mist
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05,
    );
    canvas.drawCircle(
      center,
      plateRadius * 0.72,
      Paint()
        ..color = AppColors.mist.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );

    // Semáforo.
    final housing = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: s * 0.24, height: s * 0.56),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(housing, Paint()..color = AppColors.ink);
    final lampRadius = s * 0.065;
    final colors = [AppColors.red, AppColors.orange, AppColors.green];
    for (var i = 0; i < 3; i++) {
      final lampCenter = Offset(center.dx, center.dy + (i - 1) * s * 0.165);
      canvas.drawCircle(lampCenter, lampRadius, Paint()..color = colors[i]);
    }

    // Hoja.
    final leafBase = Offset(s * 0.74, s * 0.26);
    final leaf = Path()
      ..moveTo(leafBase.dx, leafBase.dy)
      ..quadraticBezierTo(s * 0.72, s * 0.02, s * 0.97, s * 0.03)
      ..quadraticBezierTo(s * 0.99, s * 0.26, leafBase.dx, leafBase.dy)
      ..close();
    canvas.drawPath(leaf, Paint()..color = AppColors.green);
    canvas.drawLine(
      leafBase,
      Offset(leafBase.dx + s * 0.16 * math.cos(-0.85), leafBase.dy + s * 0.16 * math.sin(-0.85)),
      Paint()
        ..color = AppColors.leaf
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
