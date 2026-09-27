import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/nutri_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() => ref.read(settingsProvider.notifier).completeOnboarding(_nameController.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: NutriLogo(size: 112)),
                  const SizedBox(height: 24),
                  Text(AppConstants.appName,
                      textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    AppConstants.slogan,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  const _Feature(emoji: '📸', text: 'Fotografía tu plato y revisa los alimentos detectados.'),
                  const _Feature(emoji: '📦', text: 'Escanea productos para conocer su información nutricional.'),
                  const _Feature(emoji: '🚦', text: 'Entiende cada resultado con un semáforo explicado.'),
                  const _Feature(emoji: '💡', text: 'Recibe ideas prácticas para mejorar tus hábitos, sin dietas.'),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 30,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _start(),
                    decoration: const InputDecoration(
                      labelText: '¿Cómo te llamamos? (opcional)',
                      prefixIcon: Icon(Icons.waving_hand_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _start, child: const Text('Comenzar')),
                  const SizedBox(height: 16),
                  Text(
                    'Tus registros se guardan en tu dispositivo. NutriSemáforo es una herramienta educativa '
                    'y no reemplaza la orientación de un profesional de la salud.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35))),
          ],
        ),
      );
}
