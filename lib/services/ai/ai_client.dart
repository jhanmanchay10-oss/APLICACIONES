import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';

/// Cliente común para las funciones de IA del servidor (Supabase Edge Functions).
///
/// - Si no hay sesión, inicia una sesión de invitado automáticamente para que la
///   IA funcione sin crear cuenta (las claves de IA nunca están en la app).
/// - Convierte los errores del servidor en mensajes claros para el usuario.
class AiClient {
  const AiClient({required this.enabled});

  /// false cuando esta compilación no tiene Supabase configurado.
  final bool enabled;

  static const notConfiguredMessage =
      'La IA no está activada en esta versión de la app. Puedes agregar los alimentos manualmente.';

  SupabaseClient get _client => Supabase.instance.client;

  /// Garantiza una sesión (cuenta del usuario o invitado anónimo).
  Future<void> ensureSession() async {
    if (!enabled) throw const ConfigurationException(notConfiguredMessage);
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously().timeout(const Duration(seconds: 20));
    } on AuthException {
      throw const AccountException('Inicia sesión en tu perfil para usar la IA.');
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException();
    }
  }

  /// Llama a una función de IA y devuelve su respuesta JSON.
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await ensureSession();
    try {
      return await _call(function, body, timeout);
    } on FunctionException catch (error) {
      if (error.status == 401) {
        // La sesión pudo expirar: se renueva una vez y se reintenta.
        await _renewSession();
        try {
          return await _call(function, body, timeout);
        } on FunctionException catch (retryError) {
          throw _mapError(retryError);
        }
      }
      throw _mapError(error);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('La IA tardó demasiado en responder. Inténtalo nuevamente.');
    } on AppException {
      rethrow;
    } catch (error) {
      if (error.toString().contains('ClientException') || error.toString().contains('SocketException')) {
        throw const NetworkException();
      }
      throw const AnalysisException('No pudimos completar la solicitud. Inténtalo nuevamente.');
    }
  }

  Future<Map<String, dynamic>> _call(String function, Map<String, dynamic> body, Duration timeout) async {
    final response = await _client.functions.invoke(function, body: body).timeout(timeout);
    final data = response.data;
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map) throw const AnalysisException('La IA devolvió una respuesta inesperada.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _renewSession() async {
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      final user = _client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        await _client.auth.signOut();
        await ensureSession();
      } else {
        throw const AccountException('Tu sesión expiró. Vuelve a iniciar sesión en tu perfil.');
      }
    }
  }

  static AppException _mapError(FunctionException error) {
    final details = error.details;
    final code = details is Map ? details['error'] : null;
    return switch ((error.status, code)) {
      (429, _) => const AnalysisException(
          'Has usado la IA muchas veces seguidas. Espera unos minutos e inténtalo de nuevo.',
        ),
      (503, 'ai_not_configured') || (404, _) => const ConfigurationException(
          'La IA todavía no está activada en el servidor. Mientras tanto puedes registrar tus comidas manualmente.',
        ),
      (401, _) => const AccountException('Tu sesión expiró. Vuelve a iniciar sesión en tu perfil.'),
      (413, _) => const AnalysisException('La foto es demasiado grande. Prueba con otra.'),
      (_, 'invalid_image') ||
      (_, 'invalid_media_type') =>
        const AnalysisException('No pudimos leer la foto. Prueba con otra imagen.'),
      (502, _) || (504, _) => const NetworkException('El servicio de IA no respondió. Inténtalo en un momento.'),
      _ => const AnalysisException(),
    };
  }
}
