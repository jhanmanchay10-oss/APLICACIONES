/// Configuración inyectada en compilación con --dart-define.
/// Nunca se incluyen claves privadas: solo la URL y la clave publicable de
/// Supabase, que están diseñadas para usarse en clientes junto con RLS.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const isSupabaseConfigured = supabaseUrl != '' && supabaseKey != '';
}
