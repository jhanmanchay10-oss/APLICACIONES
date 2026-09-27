import 'package:flutter/material.dart';

/// Tarjeta de acción principal (Analizar plato, Escanear, Buscar).
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = highlighted ? scheme.primary : scheme.surfaceContainerLowest;
    final foreground = highlighted ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: highlighted ? null : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: highlighted ? scheme.onPrimary.withValues(alpha: 0.15) : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: highlighted ? scheme.onPrimary : scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: foreground)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: foreground.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: foreground.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
