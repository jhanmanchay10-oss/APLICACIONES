import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/text_utils.dart';
import '../services/ai/assistant_service.dart';
import 'core_providers.dart';
import 'meals_provider.dart';

class AssistantState {
  const AssistantState({this.messages = const [], this.sending = false, this.error});

  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  AssistantState copyWith({List<ChatMessage>? messages, bool? sending, String? error, bool clearError = false}) =>
      AssistantState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Conversación con el asistente (se conserva al cambiar de pestaña).
class AssistantNotifier extends Notifier<AssistantState> {
  @override
  AssistantState build() => const AssistantState();

  Future<void> send(String text) async {
    final question = TextUtils.sanitize(text, maxLength: AssistantService.maxQuestionLength);
    if (question.isEmpty || state.sending) return;
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(role: ChatRole.user, text: question)],
      sending: true,
      clearError: true,
    );
    await _ask();
  }

  /// Reintenta la última pregunta tras un error.
  Future<void> retry() async {
    if (state.sending || state.messages.isEmpty || state.messages.last.role != ChatRole.user) return;
    state = state.copyWith(sending: true, clearError: true);
    await _ask();
  }

  Future<void> _ask() async {
    try {
      final summary = ref.read(currentWeekSummaryProvider).value;
      final meals = ref.read(mealsProvider).value ?? const [];
      final context = AssistantService.buildContext(summary: summary, recentMeals: meals);
      final reply = await ref.read(assistantServiceProvider).ask(state.messages, context: context);
      state = state.copyWith(messages: [...state.messages, reply], sending: false);
    } catch (error) {
      state = state.copyWith(sending: false, error: friendlyError(error));
    }
  }

  void clear() => state = const AssistantState();
}

final assistantProvider = NotifierProvider<AssistantNotifier, AssistantState>(AssistantNotifier.new);
