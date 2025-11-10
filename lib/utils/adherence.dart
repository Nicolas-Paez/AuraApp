import 'package:hive/hive.dart';
import '../models/TomaMedicamento.dart';
import 'hive_boxes.dart';

/// Calcula la adherencia de un medicamento en los últimos [days] días.
/// - Se considera solo tomas con fechaProgramada >= now - days y <= now.
/// - Retorna valor en rango [0,1]. Si no hay tomas en el período, retorna 0.
Future<double> calcularAdherenciaMedicamento(
  int medicamentoKey, {
  int days = 30,
}) async {
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final box = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
  final now = DateTime.now();
  final from = now.subtract(Duration(days: days));

  final tomasPeriodo = box.values.where((t) {
    return t.medicamentoKey == medicamentoKey &&
        !t.fechaProgramada.isAfter(now) &&
        !t.fechaProgramada.isBefore(from);
  }).toList();

  if (tomasPeriodo.isEmpty) return 0.0;

  final tomadas = tomasPeriodo
      .where((t) => t.estado.toLowerCase() == 'tomada')
      .length;
  return tomadas / tomasPeriodo.length;
}

/// Calcula adherencia por día para la última semana (7 días) para un medicamento.
/// Retorna una lista de pares (Date, adherence)
Future<List<Map<String, dynamic>>> calcularAdherenciaSemanal(
  int medicamentoKey,
) async {
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final box = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
  final now = DateTime.now();

  final semana = <Map<String, dynamic>>[];
  for (int i = 6; i >= 0; i--) {
    final dia = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: i));
    final tomasDia = box.values.where((t) {
      return t.medicamentoKey == medicamentoKey &&
          t.fechaProgramada.year == dia.year &&
          t.fechaProgramada.month == dia.month &&
          t.fechaProgramada.day == dia.day &&
          !t.fechaProgramada.isAfter(now);
    }).toList();

    if (tomasDia.isEmpty) {
      semana.add({'date': dia, 'adherencia': 0.0});
    } else {
      final tomadas = tomasDia
          .where((t) => t.estado.toLowerCase() == 'tomada')
          .length;
      semana.add({'date': dia, 'adherencia': tomadas / tomasDia.length});
    }
  }
  return semana;
}
