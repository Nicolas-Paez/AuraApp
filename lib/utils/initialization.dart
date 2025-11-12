import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/TomaMedicamento.dart';
import '../models/HistorialMedicamento.dart';
import '../models/EstadoAnimico.dart';
import '../models/CambioDosis.dart';
import '../models/Medicamento.dart';
import '../models/Crisis.dart';
import 'hive_boxes.dart';
import 'initialization_state.dart';

/// Inicializa Hive de manera optimizada usando inicialización lazy y paralela.
Future<void> initializeHive() async {
  final state = InitializationState();
  state.updateStep('🚀 Iniciando servicios críticos...');
  state.updateProgress(0.1);

  // Crear un completer para manejar el timeout
  final initCompleter = Completer<void>();

  // Iniciar un timeout
  Future.delayed(const Duration(seconds: 30), () {
    if (!initCompleter.isCompleted) {
      print('! Timeout de inicialización alcanzado, forzando inicio...');
      state.updateStep('⚠️ Timeout alcanzado');
      state.isInitialized.value = true;
      initCompleter.complete();
    }
  });

  try {
    // Paso 1: Inicializar Hive con compactación automática optimizada
    state.updateStep('📂 Inicializando Hive...');
    await Hive.initFlutter();

    // Paso 2: Registrar adaptadores (proceso rápido en memoria)
    if (!Hive.isAdapterRegistered(1))
      Hive.registerAdapter(MedicamentoAdapter());
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CrisisAdapter());
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(TomaMedicamentoAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(HistorialMedicamentoAdapter());
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(EstadoAnimicoAdapter());
    if (!Hive.isAdapterRegistered(3))
      Hive.registerAdapter(CambioDosisAdapter());

    final compactionStrategy = (int entries, int deletedEntries) {
      return deletedEntries > 50 && deletedEntries > entries ~/ 2;
    };

    // Paso 3: Abrir las cajas críticas una por una para mejor manejo de errores
    state.updateStep('📦 Abriendo caja de medicamentos...');
    state.updateProgress(0.3);
    try {
      await Hive.openBox<Medicamento>(
        medicamentosBoxName,
        compactionStrategy: compactionStrategy,
      );
      state.updateBoxStatus('medicamentos', true);
    } catch (e) {
      print('Error abriendo caja de medicamentos: $e');
      state.updateBoxStatus('medicamentos', false);
      rethrow;
    }

    state.updateStep('📦 Abriendo caja de tomas de medicamentos...');
    state.updateProgress(0.5);
    try {
      await Hive.openBox<TomaMedicamento>(
        tomasMedicamentosBoxName,
        compactionStrategy: compactionStrategy,
      );
      state.updateBoxStatus('tomas_medicamentos', true);
    } catch (e) {
      print('Error abriendo caja de tomas de medicamentos: $e');
      state.updateBoxStatus('tomas_medicamentos', false);
      rethrow;
    }

    state.updateStep('📦 Abriendo caja de crisis...');
    state.updateProgress(0.7);
    try {
      await Hive.openBox<Crisis>(
        crisisBoxName,
        compactionStrategy: compactionStrategy,
      );
      state.updateBoxStatus('crisis', true);
    } catch (e) {
      print('Error abriendo caja de crisis: $e');
      state.updateBoxStatus('crisis', false);
      rethrow;
    }

    state.updateStep('📦 Abriendo caja de estado anímico...');
    state.updateProgress(0.9);
    try {
      await Hive.openBox<EstadoAnimico>(
        estadoAnimicoBoxName,
        compactionStrategy: compactionStrategy,
      );
      state.updateBoxStatus('estado_animico', true);
    } catch (e) {
      print('Error abriendo caja de estado anímico: $e');
      state.updateBoxStatus('estado_animico', false);
      rethrow;
    }

    // Paso 4: Programar apertura de cajas no críticas
    _openRemainingBoxes();

    state.updateStep('✅ Todas las cajas inicializadas');
    state.updateProgress(1.0);

    // Si todo salió bien, marcar como inicializado antes del timeout
    if (!state.isInitialized.value) {
      state.isInitialized.value = true;
      // Completar el completer para evitar que el timeout se ejecute
      try {
        if (!initCompleter.isCompleted) initCompleter.complete();
      } catch (_) {}
    }
  } catch (e) {
    print('❌ Error inicializando Hive: $e');
    state.updateStep('❌ Error en la inicialización');
    // En caso de error crítico, también marcamos como inicializado para no bloquear la app
    if (!state.isInitialized.value) {
      state.isInitialized.value = true;
      try {
        if (!initCompleter.isCompleted) initCompleter.complete();
      } catch (_) {}
    }
    rethrow;
  }
}

Future<void> _openRemainingBoxes() async {
  final state = InitializationState();
  state.updateStep('🔄 Iniciando cajas adicionales...');

  try {
    // Solo abrir las cajas que no son esenciales y que no estén ya abiertas
    if (!Hive.isBoxOpen(historialMedicamentosBoxName)) {
      try {
        await Hive.openBox<HistorialMedicamento>(
          historialMedicamentosBoxName,
          compactionStrategy: (entries, deletedEntries) =>
              deletedEntries > 50 && deletedEntries > entries ~/ 2,
        );
        state.updateBoxStatus('historial_medicamentos', true);
      } catch (e) {
        print('⚠️ Error abriendo caja de historial de medicamentos: $e');
        state.updateBoxStatus('historial_medicamentos', false);
      }
    }

    if (!Hive.isBoxOpen('cambioDosis')) {
      try {
        await Hive.openBox<CambioDosis>(
          'cambioDosis',
          compactionStrategy: (entries, deletedEntries) =>
              deletedEntries > 50 && deletedEntries > entries ~/ 2,
        );
        state.updateBoxStatus('cambio_dosis', true);
      } catch (e) {
        print('⚠️ Error abriendo caja de cambios de dosis: $e');
        state.updateBoxStatus('cambio_dosis', false);
      }
    }

    state.updateStep('✅ Cajas adicionales inicializadas');
  } catch (e) {
    print('⚠️ Error general abriendo cajas adicionales: $e');
    state.updateStep('⚠️ Error en cajas adicionales');
  }
}

// Función eliminada para evitar confusiones
