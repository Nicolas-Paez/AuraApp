import 'package:hive/hive.dart';

part 'CambioDosis.g.dart';

@HiveType(typeId: 3)
class CambioDosis extends HiveObject {
  @HiveField(0)
  final DateTime fecha;

  @HiveField(1)
  final String dosis;

  @HiveField(2)
  final String razon;

  @HiveField(3)
  final String unidad;

  @HiveField(4)
  int? medicamentoKey;

  CambioDosis({
    required this.fecha,
    required this.dosis,
    required this.razon,
    required this.unidad,
    this.medicamentoKey,
  });

  // Compatibility getters expected by UI code
  DateTime get fechaCambio => fecha;

  /// UI expects nuevaDosis as a numeric value. We store dosis as string for
  /// backward compatibility, but expose a numeric getter.
  double get nuevaDosis => double.tryParse(dosis) ?? 0.0;

  String get motivo => razon;

  Map<String, dynamic> toJson() {
    return {
      'fechaCambio': fecha.toIso8601String(),
      'nuevaDosis': nuevaDosis,
      'motivo': motivo,
      'unidad': unidad,
      'medicamentoKey': medicamentoKey,
    };
  }

  factory CambioDosis.fromJson(Map<String, dynamic> json) {
    return CambioDosis(
      fecha: DateTime.parse(
        json['fechaCambio'] ??
            json['fecha'] ??
            DateTime.now().toIso8601String(),
      ),
      dosis: (json['nuevaDosis'] ?? json['dosis'] ?? 0).toString(),
      razon: json['motivo'] ?? json['razon'] ?? '',
      unidad: json['unidad'] ?? '',
      medicamentoKey: json['medicamentoKey'],
    );
  }
}
