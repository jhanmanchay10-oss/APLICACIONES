import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../providers/meals_provider.dart';
import '../../widgets/nutri_logo.dart';

/// Inicio de sesión / registro con correo y contraseña (Supabase Auth).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_register) {
        final response = await auth.signUp(email: _email.text.trim(), password: _password.text);
        if (response.session == null) {
          if (!mounted) return;
          setState(() => _loading = false);
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Revisa tu correo'),
              content: const Text('Te enviamos un enlace para confirmar tu cuenta. Luego inicia sesión.'),
              actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
            ),
          );
          if (mounted) setState(() => _register = false);
          return;
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
      await ref.read(mealsProvider.notifier).syncPending();
      if (mounted) Navigator.pop(context);
    } on AuthApiException catch (error) {
      setState(() => _error = error.code == 'invalid_credentials'
          ? 'Correo o contraseña incorrectos.'
          : 'No pudimos completar la operación: ${error.message}');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Crear cuenta' : 'Iniciar sesión')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: NutriLogo(size: 80)),
              const SizedBox(height: 16),
              const Text(
                'Con una cuenta puedes guardar una copia de tus comidas en la nube y usar el análisis con IA.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
                validator: (value) =>
                    _emailPattern.hasMatch(value?.trim() ?? '') ? null : 'Ingresa un correo válido.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                validator: (value) =>
                    (value?.length ?? 0) >= 8 ? null : 'La contraseña debe tener al menos 8 caracteres.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? 'Crear cuenta' : 'Entrar'),
              ),
              TextButton(
                onPressed: _loading ? null : () => setState(() => _register = !_register),
                child: Text(_register ? 'Ya tengo cuenta' : 'Crear una cuenta nueva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
