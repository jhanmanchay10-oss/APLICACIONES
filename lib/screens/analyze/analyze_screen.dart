import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../models/meal.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../navigation.dart';
import '../result/meal_editor_screen.dart';

class AnalyzeScreen extends ConsumerStatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  ConsumerState<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends ConsumerState<AnalyzeScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
  }

  /// En Android la actividad puede reiniciarse mientras la cámara está abierta.
  Future<void> _recoverLostImage() async {
    if (!Platform.isAndroid) return;
    final response = await _picker.retrieveLostData();
    final file = response.file;
    if (file != null && mounted) setState(() => _image = File(file.path));
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: AppConstants.maxImageDimension,
        maxHeight: AppConstants.maxImageDimension,
        imageQuality: AppConstants.imageQuality,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _image = File(picked.path);
        _error = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      final denied = error.code.contains('access_denied') || error.code.contains('permission');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(denied
            ? 'Necesitamos permiso para usar la cámara o la galería. Puedes activarlo en los ajustes.'
            : 'No pudimos abrir la cámara o la galería.'),
      ));
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;
    final recognition = ref.read(foodRecognitionServiceProvider);

    if (!recognition.enabled) {
      _openEditor(const [], notice: 'El análisis automático no está disponible en esta versión. '
          'Agrega los alimentos de tu plato con el botón "Agregar alimento".');
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final result = await recognition.recognize(image);
      if (!mounted) return;
      _openEditor(
        result.foods,
        lowConfidence: result.isLowConfidence,
        notice: result.foods.isEmpty ? 'No pudimos identificar correctamente los alimentos. Agrégalos manualmente.' : null,
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _openEditor(List<MealFood> foods, {bool lowConfidence = false, String? notice}) {
    AppNavigation.push(
      context,
      MealEditorScreen(
        initialFoods: foods,
        photo: _image,
        source: MealSource.photo,
        lowConfidence: lowConfidence,
        notice: notice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = _image;
    final aiEnabled = ref.watch(foodRecognitionServiceProvider).enabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Analizar plato')),
      body: SafeArea(
        child: _analyzing
            ? const LoadingView(message: 'Analizando tu plato...')
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: image == null
                        ? _Placeholder(onCamera: () => _pick(ImageSource.camera))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(image, fit: BoxFit.cover, semanticLabel: 'Foto de tu plato'),
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    InfoBanner(message: _error!, tone: BannerTone.warning),
                    const SizedBox(height: 12),
                  ],
                  if (!aiEnabled) ...[
                    const InfoBanner(
                      message: 'Modo manual: guarda la foto y agrega tú los alimentos. '
                          'El análisis con IA se activa al configurar el servidor.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (image != null) ...[
                    FilledButton.icon(
                      onPressed: _analyze,
                      icon: Icon(aiEnabled ? Icons.auto_awesome : Icons.arrow_forward),
                      label: Text(aiEnabled ? 'Analizar imagen' : 'Continuar'),
                    ),
                    const SizedBox(height: 10),
                    if (_error != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => _openEditor(const []),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Agregar alimentos manualmente'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Cámara'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Consejo: toma la foto desde arriba, con buena luz y con todo el plato visible. '
                    'Los valores obtenidos de una foto siempre son estimaciones.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.onCamera});

  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onCamera,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text('Toca para tomar una foto', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
