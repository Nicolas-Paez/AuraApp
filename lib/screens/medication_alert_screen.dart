import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MedicationAlertScreen extends StatefulWidget {
  final String medicamentoNombre;
  final DateTime horaOriginal;
  final Function() onTomado;
  final Function(String razon) onNoTomado;
  final Function() onPosponer;

  const MedicationAlertScreen({
    super.key,
    required this.medicamentoNombre,
    required this.horaOriginal,
    required this.onTomado,
    required this.onNoTomado,
    required this.onPosponer,
  });

  @override
  State<MedicationAlertScreen> createState() => _MedicationAlertScreenState();
}

class _MedicationAlertScreenState extends State<MedicationAlertScreen> {
  bool _waitingReason = false;
  final TextEditingController _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reproducir sonido y vibración inmediata
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    } catch (_) {}
    // Evitar retroceso usando el nuevo mecanismo de ScopedWillPop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // addScopedWillPopCallback is deprecated on newer Flutter versions; when
      // updating to the newer navigation API replace this with PopScope or
      // registerPopEntry/unregisterPopEntry.
      // ignore: deprecated_member_use
      ModalRoute.of(context)?.addScopedWillPopCallback(_onWillPop);
    });
  }

  Future<bool> _onWillPop() async => false;

  Future<void> _handleNotTaken() async {
    setState(() => _waitingReason = true);

    final reason = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Razón por no tomar'),
          content: TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(hintText: 'Escriba la razón'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_reasonCtrl.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    setState(() => _waitingReason = false);

    if (reason == null || reason.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Razón obligatoria para "No tomado"')),
      );
      return;
    }

    widget.onNoTomado(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alarm, size: 88, color: Colors.white),
                const SizedBox(height: 8),
                const Text(
                  '¡Hora de tu medicamento!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.medicamentoNombre,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hora planificada: ${widget.horaOriginal.hour.toString().padLeft(2, '0')}:${widget.horaOriginal.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: widget.onTomado,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Tomado'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _waitingReason ? null : _handleNotTaken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('No tomado (razón obligatoria)'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: widget.onPosponer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Posponer 10 min'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    // Remover el callback añadido
    // ignore: deprecated_member_use
    ModalRoute.of(context)?.removeScopedWillPopCallback(_onWillPop);
    super.dispose();
  }
}
