# 🚦 NutriSemáforo

**Conoce lo que comes. Mejora tus hábitos.**

Aplicación Android (Flutter) que registra tus comidas por **foto**, **código de barras** o **búsqueda**, y muestra un **semáforo nutricional explicado** (verde / naranja / rojo) centrado en la calidad de la alimentación, no en las calorías.

## 📥 Descargar el APK

Cada push a este repositorio compila el APK en GitHub Actions y lo publica en **Releases**:

1. Abre la pestaña **Releases** del repositorio (o **Actions → Build APK → artefacto `NutriSemaforo-apk`**).
2. Descarga `NutriSemaforo.apk` en tu teléfono Android (7.0 o superior).
3. Ábrelo y acepta "Instalar apps de origen desconocido".

## ✨ Funciones

| Pantalla | Qué hace |
|---|---|
| 🏠 Inicio | Saludo, logo, accesos a Analizar / Escanear / Buscar, resumen de la semana, últimas comidas y consejo del día |
| 📸 Analizar plato | Cámara o galería, vista previa, análisis con IA (si está configurada) o modo manual |
| 🔎 Alimentos detectados | Editar cantidades, cambiar, eliminar (con deshacer) o agregar alimentos; aviso de baja confianza |
| 🚦 Resultado | Semáforo, "¿Por qué?", "¿Qué puedes mejorar?", nutrientes, gráfico de energía, alimentos |
| 📦 Escáner | Lector EAN/UPC + consulta en Open Food Facts (ingredientes, NOVA, Nutri-Score) |
| 📅 Historial | Comidas agrupadas por día, con foto, hora, semáforo y filtros por color |
| 📈 Mi semana | Lunes a domingo con color por día, conteos, gráfico apilado y tendencias vs. semana anterior |
| 💡 Mejorar | Recomendaciones semanales positivas y explicación transparente de los criterios |
| 👤 Perfil | Nombre, foto opcional, mostrar/ocultar calorías, tema, cuenta en la nube, privacidad y borrado de datos |

La app funciona **sin conexión y sin cuenta** (SQLite local). Supabase e IA son opcionales.

## 🏗️ Arquitectura

```
lib/
├── core/            config (Env, NutritionCriteria), constants, theme, utils, errors
├── data/            base local de ~80 alimentos (incluye platos peruanos/latinos)
├── models/          Nutrients, FoodItem, Meal, TrafficLight, NutritionAssessment, WeeklySummary
├── services/
│   ├── ai/          FoodRecognitionService (llama a la Edge Function)
│   ├── barcode/     OpenFoodFactsService
│   ├── nutrition/   NutritionAnalyzer, NutritionScore, TrafficLightService,
│   │                RecommendationEngine, WeeklySummaryService
│   ├── storage/     LocalDatabase (sqflite), PhotoStorage
│   └── sync/        CloudSyncService (Supabase)
├── repositories/    MealRepository
├── providers/       Riverpod
├── screens/         home, analyze, result, barcode, search, history, weekly,
│                    recommendations, profile, auth, onboarding, shell
└── widgets/         componentes reutilizables (logo, semáforo, tarjetas, gráficos)
supabase/
├── migrations/      esquema PostgreSQL + RLS + bucket de fotos
└── functions/analyze-meal/   Edge Function con GPT de OpenAI (visión)
```

**¿Por qué Riverpod?** Inyección de dependencias sin `BuildContext`, estado asíncrono (`AsyncNotifier`) con carga/error integrados, providers derivados (el resumen semanal se recalcula solo cuando cambian las comidas) y overrides sencillos en pruebas. Bloc sería válido, pero requiere más código repetitivo para esta escala.

**Local-first:** las comidas se guardan primero en SQLite (instantáneo y sin conexión) y, si hay sesión de Supabase, se sincronizan en segundo plano. Si la sincronización falla, se reintenta luego.

## 🚦 Sistema del semáforo

`alimentos → NutritionAnalyzer (perfil) → NutritionScore (factores) → TrafficLightService (color) → RecommendationEngine (explicación y mejoras)`

- **Suman:** frutas y verduras, fibra, fuente de proteína, variedad de grupos, cereales integrales/legumbres.
- **Restan:** azúcares añadidos (aprox.), grasas saturadas, sodio, ultraprocesados (NOVA 4).
- **Las calorías no intervienen** en el color.
- **Verde:** puntuación ≥ 2 sin nutrientes en nivel alto. **Rojo:** puntuación ≤ −3 o ≥ 2 nutrientes en nivel alto. **Naranja:** el resto.

Todos los umbrales están en un único archivo: `lib/core/config/nutrition_criteria.dart`, y pueden cargarse desde JSON (`NutritionCriteria.fromJson`) para ajustarlos sin reconstruir la app.

### ⚠️ Criterios que conviene validar con un profesional de la nutrición

1. **Umbrales por 100 g** (FSA Reino Unido): azúcares 5 / 22,5 g, grasas saturadas 1,5 / 5 g, sal 0,3 / 1,5 g. ¿Aplican igual a platos completos que a productos? (La FSA usa umbrales por porción para porciones > 100 g).
2. **Aproximación de "azúcares añadidos"**: se cuentan los azúcares de dulces, bebidas, snacks, comida rápida, cereales refinados y productos NOVA ≥ 3; los de fruta entera, verduras y lácteos naturales no.
3. **Fibra** ("fuente" ≥ 3 g/100 g, "alto" ≥ 6 g/100 g, Reglamento UE 1924/2006) y **proteína** (≥ 12 % de la energía).
4. **Metas semanales** (OMS): ≥ 400 g/día de frutas y verduras, azúcares libres < 50 g/día, sodio < 2000 mg/día, fibra ≥ 25 g/día.
5. **Pesos de cada factor** (+2/+1/−1/−2) y los cortes de color.
6. **Valores de la base local**, especialmente los platos preparados (promedios estimados).
7. Adecuación para **niños, embarazo o condiciones de salud** (la app no está pensada para ellos).

## ☁️ Configurar Supabase + IA (opcional)

1. Crea un proyecto en [supabase.com](https://supabase.com) e instala el [CLI](https://supabase.com/docs/guides/cli).
2. Aplica el esquema (tablas, RLS y bucket privado `meal-photos`):
   ```bash
   supabase link --project-ref TU_PROYECTO
   supabase db push
   ```
3. Despliega la función de IA con tu clave de OpenAI (GPT) (solo vive en el servidor):
   ```bash
   supabase secrets set OPENAI_API_KEY=sk-...
   supabase functions deploy analyze-meal
   ```
4. En GitHub → *Settings → Secrets and variables → Actions*, agrega `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. El siguiente build activará cuenta, sincronización y análisis de fotos.

**Seguridad:** RLS en todas las tablas (cada usuario solo ve sus registros), fotos en carpetas por usuario, la app solo contiene la clave *publicable*, la clave de IA está en los secretos del servidor, la función exige sesión y limita a 20 análisis/hora por usuario, y todas las entradas se validan.

### Cambios al esquema propuesto
- `meal_foods` guarda una **copia** del nombre, categoría, NOVA y nutrientes: el historial no cambia si se corrige el catálogo, y los alimentos detectados por IA no necesitan fila en `foods`.
- `meal_foods.user_id` para políticas RLS simples y rápidas.
- `meals` añade `score`, `source` e `is_estimate`; `profiles` añade `show_calories`.
- Tabla `ai_usage` para limitar el uso de la IA.

## 🛠️ Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run                      # modo local, sin nube
flutter run --dart-define-from-file=dart_defines.json   # con Supabase (copia dart_defines.example.json)
flutter build apk --release      # APK en build/app/outputs/flutter-apk/
```

Regenerar icono y splash tras cambiar `assets/branding/`:
```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Antes de publicar en Google Play
- Crear un keystore propio y configurar `signingConfig` de release (hoy se firma con la clave de depuración, válida para instalar el APK directamente).
- Generar `flutter build appbundle`.
- Publicar una política de privacidad.

---
Herramienta educativa: no reemplaza la orientación de un profesional de la salud. Datos de productos: [Open Food Facts](https://world.openfoodfacts.org) (ODbL).
