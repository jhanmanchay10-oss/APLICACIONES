import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';

/// Usuario de Supabase actual; siempre null si Supabase no está configurado.
final currentUserProvider = StreamProvider<User?>((ref) async* {
  if (!Env.isSupabaseConfigured) {
    yield null;
    return;
  }
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser;
  yield* auth.onAuthStateChange.map((state) => state.session?.user);
});
