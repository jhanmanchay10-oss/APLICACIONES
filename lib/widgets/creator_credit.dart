import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// Crédito del creador de la aplicación.
class CreatorCredit extends StatelessWidget {
  const CreatorCredit({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: AppConstants.creatorCredit,
      excludeSemantics: true,
      child: Column(
        children: [
          Text('Creado por', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 2),
          Text(
            AppConstants.creatorName.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          Text(
            '${AppConstants.creatorSchool} · ${AppConstants.creatorGrade}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
