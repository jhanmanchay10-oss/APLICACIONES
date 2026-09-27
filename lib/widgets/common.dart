import 'dart:io';

import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, required this.message, this.action});

  final String emoji;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(message!, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            ],
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        emoji: '😕',
        title: 'Algo salió mal',
        message: message,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      );
}

enum BannerTone { info, warning }

/// Aviso destacado (estimaciones, baja confianza, modo sin conexión, etc.).
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.tone = BannerTone.info, this.icon});

  final String message;
  final BannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = tone == BannerTone.warning;
    final background = warning ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final foreground = warning ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: warning,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? (warning ? Icons.warning_amber_rounded : Icons.info_outline), color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: foreground, height: 1.35))),
          ],
        ),
      ),
    );
  }
}

/// Foto de una comida guardada localmente, con un marcador si no existe.
class MealPhoto extends StatelessWidget {
  const MealPhoto({super.key, required this.path, this.size, this.fallbackEmoji = '🍽️', this.radius = 14});

  final String? path;
  final double? size;
  final String fallbackEmoji;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final exists = file != null && file.existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: exists
            ? Image.file(file, fit: BoxFit.cover, cacheWidth: size == null ? null : (size! * 3).round())
            : ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Center(child: Text(fallbackEmoji, style: TextStyle(fontSize: (size ?? 60) * 0.45))),
              ),
      ),
    );
  }
}
