import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/assistant_provider.dart';
import '../../providers/core_providers.dart';
import '../../services/ai/assistant_service.dart';
import '../../widgets/common.dart';
import '../../widgets/nutri_logo.dart';

/// Asistente de nutrición con IA: respuestas fundamentadas en fuentes confiables
/// y recomendaciones personalizadas con tus registros.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialQuestion});

  /// Pregunta que se envía al abrir (ej. desde el resultado de un plato).
  final String? initialQuestion;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const suggestions = [
    '¿Cómo puedo mejorar mi semana?',
    'Ideas de desayuno peruano equilibrado',
    '¿Cuánta agua debo tomar al día?',
    '¿Qué alimentos tienen más fibra?',
    '¿Cómo reducir el azúcar sin dejar de disfrutar?',
    '¿Qué significan los octógonos?',
  ];

  @override
  void initState() {
    super.initState();
    final question = widget.initialQuestion;
    if (question != null && ref.read(assistantServiceProvider).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(question));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    final future = ref.read(assistantProvider.notifier).send(text);
    _scrollToEnd();
    await future;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final enabled = ref.watch(assistantServiceProvider).enabled;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            NutriLogo(size: 32),
            SizedBox(width: 10),
            Text('Asistente Nutri'),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Nueva conversación',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: state.sending ? null : ref.read(assistantProvider.notifier).clear,
            ),
        ],
      ),
      body: !enabled
          ? const EmptyState(
              emoji: '🤖',
              title: 'Asistente no disponible',
              message: 'El asistente con IA se activa cuando la app se compila con el servidor configurado. '
                  'Mientras tanto, revisa la sección "Mejorar" de tu semana.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (state.messages.isEmpty) _Welcome(onSuggestion: _send),
                      for (final message in state.messages) _Bubble(message: message),
                      if (state.sending) const _Thinking(),
                      if (state.error != null) ...[
                        InfoBanner(message: state.error!, tone: BannerTone.warning),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: ref.read(assistantProvider.notifier).retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: AssistantService.maxQuestionLength,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _send,
                            decoration: const InputDecoration(
                              hintText: 'Pregúntale a Nutri…',
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Enviar',
                          onPressed: state.sending ? null : () => _send(_input.text),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¡Hola! Soy Nutri 👋',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
              const SizedBox(height: 8),
              Text(
                'Respondo tus dudas de alimentación con información de fuentes confiables '
                '(OMS, MINSA, INS y universidades) y te doy ideas según lo que registras.',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Prueba preguntando:', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in _AssistantScreenState.suggestions)
              ActionChip(label: Text(suggestion), onPressed: () => onSuggestion(suggestion)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Información educativa: no reemplaza la consulta con un profesional de la salud.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  Future<void> _open(BuildContext context, ChatSource source) async {
    final opened = await launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pudimos abrir el enlace.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                message.text,
                style: TextStyle(color: isUser ? scheme.onPrimary : scheme.onSurface, height: 1.45, fontSize: 15),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Fuentes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final source in message.sources)
                      Tooltip(
                        message: source.title,
                        child: ActionChip(
                          avatar: const Icon(Icons.verified_outlined, size: 16),
                          label: Text(source.domain, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _open(context, source),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Nutri está consultando fuentes confiables…',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
