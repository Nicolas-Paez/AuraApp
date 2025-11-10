import 'package:hive_flutter/hive_flutter.dart';
import '../models/Crisis.dart';
import '../models/Medicamento.dart';
import '../models/EstadoAnimico.dart';
import '../models/TomaMedicamento.dart';
import 'hive_boxes.dart';

Future<void> migrateData() async {
  print('🔄 Iniciando migración de datos...');

  try {
    // Primero, eliminar cualquier box corrupto
    try {
      await Hive.deleteBoxFromDisk(estadoAnimicoBoxName);
      await Hive.deleteBoxFromDisk(tomasMedicamentosBoxName);
      print('✅ Boxes corruptos eliminados');
    } catch (e) {
      print('⚠️ Error limpiando boxes corruptos: $e');
    }

    // Migrar Crisis
    try {
      final crisisBox = await Hive.openBox<Crisis>(crisisBoxName);
      for (var key in crisisBox.keys) {
        try {
          final crisis = crisisBox.get(key);
          if (crisis != null) {
            // Asegurar que medicamentoRescateKey sea int
            if (crisis.medicamentoRescateKey is String) {
              crisis.medicamentoRescateKey = int.tryParse(
                crisis.medicamentoRescateKey as String,
              );
              await crisis.save();
            }
          }
        } catch (e) {
          print('⚠️ Error migrando crisis $key: $e');
        }
      }
      print('✅ Migración de crisis completada');
    } catch (e) {
      print('❌ Error en migración de crisis: $e');
    }

    // Migrar Medicamentos
    try {
      final medBox = await Hive.openBox<Medicamento>(medicamentosBoxName);
      for (var key in medBox.keys) {
        try {
          final med = medBox.get(key);
          if (med != null) {
            bool needsSave = false;

            // Asegurar que dosis sea double
            if (med.dosis is String) {
              med.dosis = double.tryParse(med.dosis as String) ?? 0.0;
              needsSave = true;
            }

            // Asegurar que fechaInicio sea DateTime
            if (med.fechaInicio is String) {
              med.fechaInicio =
                  DateTime.tryParse(med.fechaInicio as String) ??
                  DateTime.now();
              needsSave = true;
            }

            if (needsSave) {
              await med.save();
            }
          }
        } catch (e) {
          print('⚠️ Error migrando medicamento $key: $e');
        }
      }
      print('✅ Migración de medicamentos completada');
    } catch (e) {
      print('❌ Error en migración de medicamentos: $e');
    }

    // Crear nuevos boxes para estado anímico y tomas de medicamentos
    try {
      await Hive.openBox<EstadoAnimico>(estadoAnimicoBoxName);
      await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
      print('✅ Nuevos boxes creados correctamente');
    } catch (e) {
      print('❌ Error creando nuevos boxes: $e');
    }

    print('✅ Migración completada');
  } catch (e, stack) {
    print('❌ Error durante la migración: $e');
    print('Stack trace: $stack');
    // No lanzamos el error para permitir que la app continúe
  }
}
