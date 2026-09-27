import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/meals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/nutri_logo.dart';
import '../auth/auth_screen.dart';
import '../navigation.dart';
import '../recommendations/criteria_screen.dart';
import '../shell/app_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (picked == null) return;
      final path = await ref.read(photoStorageProvider).saveAvatar(File(picked.path));
      await ref.read(settingsProvider.notifier).setAvatar(path);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await ref.read(settingsProvider.notifier).setName(name);
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todos tus datos?'),
        content: const Text(
          'Se eliminarán tus comidas, fotos y preferencias de este dispositivo. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar todo')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(mealsProvider.notifier).removeAll();
    await ref.read(settingsProvider.notifier).reset();
    ref.read(tabIndexProvider.notifier).select(AppTab.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider).value;
    final mealCount = ref.watch(mealsProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: 'Cambiar foto de perfil',
                  child: GestureDetector(
                    onTap: () => _pickAvatar(context, ref),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: settings.avatarPath != null && File(settings.avatarPath!).existsSync()
                              ? FileImage(File(settings.avatarPath!))
                              : null,
                          child: settings.avatarPath == null ? const Text('🙂', style: TextStyle(fontSize: 40)) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(Icons.edit, size: 16, color: theme.colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(settings.userName.isEmpty ? 'Sin nombre' : settings.userName, style: theme.textTheme.titleLarge),
                Text('$mealCount comidas registradas', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Datos'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Nombre'),
                  subtitle: Text(settings.userName.isEmpty ? 'Toca para agregar' : settings.userName),
                  onTap: () => _editName(context, ref, settings.userName),
                ),
                if (settings.avatarPath != null)
                  ListTile(
                    leading: const Icon(Icons.hide_image_outlined),
                    title: const Text('Quitar foto de perfil'),
                    onTap: () => ref.read(settingsProvider.notifier).setAvatar(null),
                  ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Ver historial'),
                  onTap: () => ref.read(tabIndexProvider.notifier).select(AppTab.history),
                ),
              ],
            ),
          ),
          const SectionHeader('Preferencias'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.local_fire_department_outlined),
                  title: const Text('Mostrar calorías'),
                  subtitle: const Text('Desactívalo para centrarte solo en la calidad de tus comidas'),
                  value: settings.showCalories,
                  onChanged: ref.read(settingsProvider.notifier).setShowCalories,
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Tema'),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (mode) {
                      if (mode != null) ref.read(settingsProvider.notifier).setThemeMode(mode);
                    },
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Cuenta y nube'),
          Card(
            child: !Env.isSupabaseConfigured
                ? const ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Modo local'),
                    subtitle: Text('Tus datos se guardan solo en este dispositivo. '
                        'La cuenta en la nube se activa cuando se configura el servidor.'),
                  )
                : user == null
                    ? ListTile(
                        leading: const Icon(Icons.login),
                        title: const Text('Iniciar sesión'),
                        subtitle: const Text('Respalda tus comidas y usa el análisis con IA'),
                        onTap: () => AppNavigation.push(context, const AuthScreen()),
                      )
                    : Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.cloud_done_outlined),
                            title: Text(user.email ?? 'Cuenta activa'),
                            subtitle: const Text('Tus comidas se sincronizan automáticamente'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.sync),
                            title: const Text('Sincronizar ahora'),
                            onTap: () async {
                              final count = await ref.read(mealsProvider.notifier).syncPending();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$count comidas sincronizadas')),
                                );
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Cerrar sesión'),
                            onTap: () => Supabase.instance.client.auth.signOut(),
                          ),
                        ],
                      ),
          ),
          const SectionHeader('Privacidad'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Tus datos son tuyos'),
                  subtitle: Text('Solo pedimos lo necesario. Las fotos se guardan en tu dispositivo y, '
                      'si inicias sesión, en tu espacio privado de la nube.'),
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                  title: Text('Borrar todos mis datos', style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () => _deleteAll(context, ref),
                ),
              ],
            ),
          ),
          const SectionHeader('Acerca de'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.traffic_outlined),
                  title: const Text('¿Cómo funciona el semáforo?'),
                  onTap: () => AppNavigation.push(context, const CriteriaScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text(AppConstants.appName),
                  subtitle: const Text('Versión ${AppConstants.version}'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: AppConstants.version,
                    applicationIcon: const NutriLogo(size: 48),
                    applicationLegalese: 'Herramienta educativa. No reemplaza la orientación de un profesional '
                        'de la salud. Datos de productos: Open Food Facts (ODbL).',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
