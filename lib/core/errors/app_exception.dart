/// Errores de dominio con mensajes listos para mostrar al usuario.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No hay conexión. Inténtalo nuevamente.']);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class AnalysisException extends AppException {
  const AnalysisException([super.message = 'No pudimos identificar correctamente los alimentos.']);
}

class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}

class AccountException extends AppException {
  const AccountException(super.message);
}

class StorageException extends AppException {
  const StorageException([super.message = 'No pudimos guardar la información en tu dispositivo.']);
}

/// Convierte cualquier error en un mensaje comprensible.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed host lookup')) {
    return const NetworkException().message;
  }
  if (text.contains('TimeoutException')) return 'La solicitud tardó demasiado. Inténtalo nuevamente.';
  return 'Ocurrió un error inesperado. Inténtalo nuevamente.';
}
