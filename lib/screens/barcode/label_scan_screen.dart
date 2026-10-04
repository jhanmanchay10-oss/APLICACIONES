import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import 'product_screen.dart';

/// Lee con IA la tabla nutricional del envase cuando el código de barras no está
/// en la base de productos. El resultado se guarda en el teléfono para la próxima vez.
class LabelScanScreen extends ConsumerStatefulWidget {
  const LabelScanScreen({super.key, this.barcode});

  final String? barcode;

  @override
  ConsumerState<LabelScanScreen> createState() => _LabelScanScreenState();
}

class _LabelScanScreenState extends ConsumerState<LabelScanScreen> {
  final _picker = ImagePicker();
  File? _photo;
  bool _reading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: AppConstants.imageQuality,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _photo = File(picked.path);
        _error = null;
      });
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitamos permiso para usar la cámara o la galería.')),
      );
    }
  }

  Future<void> _read() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final product = await ref.read(labelReaderServiceProvider).read(photo, barcode: widget.barcode);
      await ref.read(productRepositoryProvider).save(product);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ProductScreen(product: product)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = _photo;
    return Scaffold(
      appBar: AppBar(title: const Text('Leer etiqueta con IA')),
      body: SafeArea(
        child: _reading
            ? const LoadingView(message: 'Leyendo la etiqueta…')
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (photo == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🏷️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 10),
                            Text('Fotografía la tabla nutricional', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text('• Enfoca la tabla de "Información nutricional".\n'
                                '• Que los números se lean bien y con buena luz.\n'
                                '• Si puedes, incluye los octógonos de advertencia.'),
                          ],
                        ),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(photo, height: 320, fit: BoxFit.cover, semanticLabel: 'Foto de la etiqueta'),
                    ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    InfoBanner(message: _error!, tone: BannerTone.warning),
                    const SizedBox(height: 12),
                  ],
                  if (photo != null) ...[
                    FilledButton.icon(
                      onPressed: _read,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Leer etiqueta'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(photo == null ? 'Tomar foto' : 'Otra foto'),
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
                  if (widget.barcode != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Código ${widget.barcode}: lo guardaremos en tu teléfono para reconocerlo al instante la próxima vez.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
