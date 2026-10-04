import '../../core/errors/app_exception.dart';
import '../../core/utils/text_utils.dart';
import '../../models/meal.dart';
import '../../models/traffic_light.dart';
import '../../models/weekly_summary.dart';
import 'ai_client.dart';

enum ChatRole { user, assistant }

class ChatSource {
  const ChatSource({required this.title, required this.url});

  final String title;
  final String url;

  /// Dominio legible (ej. "who.int") para mostrar en la app.
  String get domain {
    final host = Uri.tryParse(url)?.host ?? url;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.sources = const []});

  final ChatRole role;
  final String text;
  final List<ChatSource> sources;
}

/// Asistente de nutrición con IA: responde con información fundamentada
/// (fuentes oficiales y académicas) y personalizada con los registros del usuario.
class AssistantService {
  const AssistantService(this._client);

  final AiClient _client;

  bool get enabled => _client.enabled;

  static const maxQuestionLength = 1000;

  Future<ChatMessage> ask(List<ChatMessage> conversation, {String context = ''}) async {
    final history = conversation.length > 12 ? conversation.sublist(conversation.length - 12) : conversation;
    final json = await _client.invoke(
      'nutrition-assistant',
      {
        'messages': [
          for (final message in history)
            {
              'role': message.role.name,
              'content': TextUtils.sanitize(message.text, maxLength: 2000),
            },
        ],
        'context': context,
      },
      timeout: const Duration(seconds: 100),
    );

    final reply = (json['reply'] as String?)?.trim() ?? '';
    if (reply.isEmpty) throw const AnalysisException('El asistente no pudo responder. Inténtalo nuevamente.');
    final sources = <ChatSource>[];
    for (final raw in (json['sources'] as List?)?.whereType<Map>() ?? const <Map>[]) {
      final url = raw['url'];
      if (url is! String || !url.startsWith('https://')) continue;
      final title = raw['title'];
      sources.add(ChatSource(title: title is String && title.isNotEmpty ? title : url, url: url));
    }
    return ChatMessage(role: ChatRole.assistant, text: reply, sources: sources);
  }

  /// Resumen breve (sin datos personales) de los registros para personalizar respuestas.
  static String buildContext({WeeklySummary? summary, List<Meal> recentMeals = const []}) {
    final lines = <String>[];
    final trends = summary?.current;
    if (summary != null && trends != null && trends.hasData) {
      lines.add('Semana actual: ${trends.mealCount} comidas en ${trends.daysWithMeals} días.');
      lines.add('Semáforo de comidas: ${summary.countMeals(TrafficLight.green)} verdes, '
          '${summary.countMeals(TrafficLight.orange)} naranjas, ${summary.countMeals(TrafficLight.red)} rojas.');
      lines.add('Promedios por día: frutas y verduras ${trends.fruitVegServingsPerDay.toStringAsFixed(1)} porciones, '
          'fibra ${trends.fiberPerDay.toStringAsFixed(0)} g, azúcares añadidos aprox. '
          '${trends.addedSugarPerDay.toStringAsFixed(0)} g, sodio ${trends.sodiumMgPerDay.toStringAsFixed(0)} mg.');
      lines.add('Variedad: ${trends.distinctFoods} alimentos distintos, '
          '${trends.proteinSourceTypes} tipos de fuentes de proteína, '
          '${trends.ultraProcessedMeals} comidas con ultraprocesados.');
    } else {
      lines.add('El usuario aún no tiene comidas registradas esta semana.');
    }
    if (recentMeals.isNotEmpty) {
      lines.add('Últimas comidas:');
      for (final meal in recentMeals.take(6)) {
        final foods = meal.foods.map((item) => item.food.name).take(6).join(', ');
        lines.add('- ${meal.name} (${meal.trafficLight.label.toLowerCase()}): $foods');
      }
    }
    return lines.join('\n');
  }
}
