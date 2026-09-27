import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nutrisemaforo/app.dart';
import 'package:nutrisemaforo/models/meal.dart';
import 'package:nutrisemaforo/providers/core_providers.dart';
import 'package:nutrisemaforo/providers/meals_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMealsNotifier extends MealsNotifier {
  @override
  Future<List<Meal>> build() async => const [];
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<void> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        mealsProvider.overrideWith(_FakeMealsNotifier.new),
      ],
      child: const NutriSemaforoApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('la bienvenida lleva a la pantalla de inicio', (tester) async {
    await pumpApp(tester, {});
    expect(find.text('NutriSemáforo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.ensureVisible(find.text('Comenzar'));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.textContaining(', Ana'), findsOneWidget);
    expect(find.text('Analizar plato'), findsOneWidget);
    expect(find.text('Escanear producto'), findsOneWidget);
    expect(find.text('Buscar alimento'), findsOneWidget);
  });

  testWidgets('la navegación inferior muestra todas las secciones', (tester) async {
    await pumpApp(tester, {'onboarding_done': true});
    for (final (tab, title) in [
      ('Historial', 'Tu historial está vacío'),
      ('Semana', 'Mi semana'),
      ('Mejorar', '¿Qué puedes mejorar?'),
      ('Perfil', 'Preferencias'),
    ]) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets, reason: tab);
    }
  });

  testWidgets('buscar un alimento y confirmarlo muestra el semáforo', (tester) async {
    await pumpApp(tester, {'onboarding_done': true});
    await tester.tap(find.text('Buscar alimento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lentejas');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lentejas').first);
    await tester.pumpAndSettle();

    final confirm = find.text('Confirmar alimentos');
    await tester.dragUntilVisible(confirm, find.byType(ListView), const Offset(0, -200));
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Resultado'), findsOneWidget);
    expect(find.text('🟢 VERDE'), findsOneWidget);
    expect(find.text('¿Por qué?'), findsOneWidget);
  });
}
