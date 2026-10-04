import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors/app_exception.dart';
import '../../providers/core_providers.dart';
import '../../services/barcode/open_food_facts_service.dart';
import '../../widgets/common.dart';
import '../navigation.dart';
import 'label_scan_screen.dart';
import 'product_screen.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _loading = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_loading) return;
    final code = capture.barcodes.map((barcode) => barcode.rawValue).whereType<String>().firstOrNull;
    if (code == null || !OpenFoodFactsService.isValidBarcode(code)) return;
    await _lookup(code);
  }

  Future<void> _lookup(String code) async {
    setState(() => _loading = true);
    await _controller.stop();
    try {
      final product = await ref.read(productRepositoryProvider).byBarcode(code);
      if (!mounted) return;
      await AppNavigation.push(context, ProductScreen(product: product));
    } on NotFoundException {
      if (!mounted) return;
      await _showNotFound(code);
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin conexión'),
          content: Text(friendlyError(error)),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        unawaited(_controller.start());
      }
    }
  }

  Future<void> _showNotFound(String code) async {
    final aiEnabled = ref.read(labelReaderServiceProvider).enabled;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Producto no encontrado', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                aiEnabled
                    ? 'El código $code aún no está en la base de productos. Fotografía la tabla nutricional '
                        'y la IA la leerá por ti.'
                    : 'El código $code aún no está en la base de productos. Puedes buscar el alimento por su nombre.',
              ),
              const SizedBox(height: 20),
              if (aiEnabled) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'label'),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Leer etiqueta con IA'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'search'),
                icon: const Icon(Icons.search),
                label: const Text('Buscar por nombre'),
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Escanear otro')),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'label') {
      await AppNavigation.push(context, LabelScanScreen(barcode: code));
    } else if (choice == 'search') {
      await AppNavigation.searchFood(context);
    }
  }

  Future<void> _enterManually() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _ManualCodeDialog());
    if (code != null && mounted) await _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear producto'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            color: Colors.white,
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: EmptyState(
                emoji: '📷',
                title: 'No pudimos abrir la cámara',
                message: error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Activa el permiso de cámara en los ajustes o escribe el código manualmente.'
                    : 'Escribe el código de barras manualmente.',
                action: FilledButton(onPressed: _enterManually, child: const Text('Escribir código')),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: SafeArea(
              child: Column(
                children: [
                  Text(
                    _loading ? 'Buscando producto…' : 'Apunta al código de barras del envase',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    FilledButton.tonalIcon(
                      onPressed: _enterManually,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Escribir código manualmente'),
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

class _ManualCodeDialog extends StatefulWidget {
  const _ManualCodeDialog();

  @override
  State<_ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<_ManualCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (!OpenFoodFactsService.isValidBarcode(code)) {
      setState(() => _error = 'Ingresa entre 6 y 14 dígitos.');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Código de barras'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 14,
          decoration: InputDecoration(hintText: 'Ej. 7750182001234', errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Buscar')),
        ],
      );
}
