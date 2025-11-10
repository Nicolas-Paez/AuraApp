import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../models/TomaMedicamento.dart';
import '../models/Medicamento.dart';
import '../utils/hive_boxes.dart';
import 'navigation.dart';

class AlarmOverlayPage extends StatefulWidget {
  final TomaMedicamento toma;
  final VoidCallback? onDismiss;

  const AlarmOverlayPage({Key? key, required this.toma, this.onDismiss})
    : super(key: key);

  @override
  State<AlarmOverlayPage> createState() => _AlarmOverlayPageState();
}

class _AlarmOverlayPageState extends State<AlarmOverlayPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  bool _procesando = false;
  Medicamento? _medicamento;
  bool _closing = false;
  Timer? _pausedTimer;
  late final ValueNotifier<double> _animationValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animationValue = ValueNotifier(0.0);
    _controller.addListener(() {
      _animationValue.value = _controller.value;
    });

    _cargarMedicamento();

    // Initial vibration and sound
    Future.delayed(const Duration(milliseconds: 500), () {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  Future<void> _cargarMedicamento() async {
    try {
      final medBox = Hive.box<Medicamento>(medicamentosBoxName);
      final med = medBox.get(widget.toma.medicamentoKey);
      if (mounted) setState(() => _medicamento = med);
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar medicamento: $e');
    }
  }

  Future<void> _stopVibrationAndSound() async {
    // No-op as there's no cross-platform way to cancel vibrations/sounds
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pausedTimer?.cancel();
    _stopVibrationAndSound();
    _animationValue.dispose();
    super.dispose();
  }

  Future<void> _cerrarOverlay() async {
    if (!mounted) return;
    await _stopVibrationAndSound();

    try {
      _controller.stop();
      await _controller.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } catch (_) {}

    if (mounted && !_closing) {
      _closing = true;
      try {
        final channel = MethodChannel('com.example.aura3/screen_state');
        await channel.invokeMethod('hideOverLockscreen');
      } on MissingPluginException catch (_) {
        // Native plugin not available on this platform/build — ignore.
        debugPrint(
          'hideOverLockscreen: native implementation not found (ignored)',
        );
      } catch (e) {
        debugPrint('Error al limpiar flags de lockscreen: $e');
      }
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    }
  }

  /// Ensure the provided [toma] is a boxed Hive object. If it's not boxed,
  /// attempt to find a matching boxed entry in the toma box (by medicamentoKey
  /// and fechaProgramada). If none exists, add the provided [toma] to the box
  /// and return the boxed instance. Returns null on unrecoverable errors.
  Future<TomaMedicamento?> _ensureBoxedToma(TomaMedicamento toma) async {
    try {
      // If it already has a key, it's boxed
      if (toma.key != null) return toma;

      if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
        await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
      }
      final box = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

      // Try to find an existing boxed toma that matches this one
      try {
        final found = box.values.firstWhere(
          (t) =>
              t.medicamentoKey == toma.medicamentoKey &&
              t.fechaProgramada.isAtSameMomentAs(toma.fechaProgramada),
        );
        return found;
      } catch (_) {
        // Not found: add the passed toma to the box so it becomes boxed
        final newKey = await box.add(
          TomaMedicamento(
            medicamentoKey: toma.medicamentoKey,
            medicamentoNombre: toma.medicamentoNombre,
            fechaProgramada: toma.fechaProgramada,
            estado: toma.estado,
            fechaReal: toma.fechaReal,
            razon: toma.razon,
            retraso: toma.retraso,
          ),
        );
        final boxed = box.get(newKey);
        debugPrint('alarm_overlay: boxed toma created with key=$newKey');
        return boxed;
      }
    } catch (e) {
      debugPrint('alarm_overlay._ensureBoxedToma error: $e');
      return null;
    }
  }

  Future<void> _dismissWithoutMarking() async {
    if (_procesando || _closing) return;
    await _cerrarOverlay();
  }

  Future<void> _marcarYSalir(String estado, {String? razon}) async {
    if (_procesando || _closing) return;
    setState(() => _procesando = true);

    try {
      // Ensure we operate on a boxed instance to safely call .save()
      final original = widget.toma;
      final toma = await _ensureBoxedToma(original);
      if (toma == null) throw Exception('No boxed TomaMedicamento available');

      toma.estado = estado;
      toma.fechaReal = DateTime.now();
      if (estado == 'No tomada') toma.razon = razon;
      try {
        toma.retraso = toma.fechaReal!
            .difference(toma.fechaProgramada)
            .inMinutes;
      } catch (_) {}

      await toma.save();

      // Show confirmation notification
      switch (estado) {
        case 'Tomada':
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 9999,
              channelKey: 'med_channel',
              title: '✅ ¡Medicamento tomado!',
              body: 'Has registrado ${toma.medicamentoNombre} como tomado.',
              autoDismissible: true,
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
          break;
        case 'No tomada':
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 9998,
              channelKey: 'med_channel',
              title: '❌ Medicamento no tomado',
              body:
                  'Has registrado ${toma.medicamentoNombre} como no tomado.\nRazón: $razon',
              autoDismissible: true,
              backgroundColor: const Color(0xFFf44336),
            ),
          );
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toma marcada como "$estado"'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _cerrarOverlay();
    } catch (e) {
      debugPrint('Error guardando toma: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
      try {
        if (mounted && !_closing) await _cerrarOverlay();
      } catch (e) {
        debugPrint('Error intentando cerrar overlay en finally: $e');
      }
    }
  }

  Future<void> _posponer() async {
    if (_procesando || _closing) return;
    setState(() => _procesando = true);

    try {
      final original = widget.toma;
      final toma = await _ensureBoxedToma(original);
      if (toma == null)
        throw Exception('No boxed TomaMedicamento available for snooze');

      final nuevaFecha = DateTime.now().add(const Duration(minutes: 10));
      toma.estado = 'Pospuesta';
      toma.fechaProgramada = nuevaFecha;
      await toma.save();

      // Schedule new notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: nuevaFecha.millisecondsSinceEpoch ~/ 1000,
          channelKey: 'med_channel',
          title: '🔔 Recordatorio de medicamento',
          body: '${toma.medicamentoNombre}\n(Pospuesto)',
          wakeUpScreen: true,
          category: NotificationCategory.Alarm,
        ),
        schedule: NotificationCalendar.fromDate(date: nuevaFecha),
        actionButtons: [
          NotificationActionButton(
            key: 'TAKEN',
            label: 'TOMADO',
            color: Colors.green,
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'NOT_TAKEN',
            label: 'NO TOMADO',
            color: Colors.red,
            actionType: ActionType.Default,
            requireInputText: true,
          ),
        ],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicamento pospuesto 10 minutos'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _cerrarOverlay();
    } catch (e) {
      debugPrint('Error posponiendo toma: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _mostrarDialogoRazon() async {
    final TextEditingController razonController = TextEditingController();
    final razon = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Motivo de no tomar el medicamento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: razonController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Ej: se me olvidó, no me sentía bien...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, razonController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (razon != null && razon.isNotEmpty) {
      await _marcarYSalir('No tomada', razon: razon);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AlarmOverlay lifecycle: $state');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedTimer?.cancel();
      _pausedTimer = Timer(const Duration(seconds: 5), () async {
        debugPrint('AlarmOverlay paused too long; dismissing overlay');
        if (mounted && !_closing) await _dismissWithoutMarking();
      });
    } else if (state == AppLifecycleState.resumed) {
      _pausedTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final toma = widget.toma;
    final med = _medicamento;
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = size.height - padding.top - padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _dismissWithoutMarking();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.red.shade800,
        body: SafeArea(
          child: Column(
            children: [
              // Top section with medication info (40% of height)
              SizedBox(
                height: availableHeight * 0.4,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _animationValue,
                      builder: (context, value, child) {
                        return AnimatedOpacity(
                          opacity: 0.4 + (value * 0.6),
                          duration: const Duration(milliseconds: 100),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                med?.nombre ?? toma.medicamentoNombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (med != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Dosis: ${med.dosis} ${med.unidad}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 24,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Middle section with notes if any
              if (med?.notas?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      med!.notas!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const Spacer(),

              // Time indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Hora programada: ${toma.fechaProgramada.hour.toString().padLeft(2, '0')}:${toma.fechaProgramada.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Bottom section with action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_procesando)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 28),
                        label: const Text(
                          'Tomado',
                          style: TextStyle(fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _marcarYSalir('Tomada'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 28),
                        label: const Text(
                          'No tomado',
                          style: TextStyle(fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _mostrarDialogoRazon,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.snooze, size: 28),
                        label: const Text(
                          'Posponer 10 min',
                          style: TextStyle(fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _posponer,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
