import 'package:hive/hive.dart';
import 'CambioDosis.dart';

part 'HistorialMedicamento.g.dart';

@HiveType(typeId: 5)
class HistorialMedicamento extends HiveObject {
  @HiveField(0)
  final DateTime fechaInicio;

  @HiveField(1)
  DateTime? fechaFin;

  @HiveField(2)
  final String medicamento;

  @HiveField(3)
  final String dosis;

  @HiveField(4)
  final String unidad;

  @HiveField(5)
  final String? razonFin;

  @HiveField(6)
  final List<CambioDosis> cambiosDosis;

  @HiveField(7)
  final String? efectosSecundarios;

  @HiveField(8)
  final String? notasEficacia;

  HistorialMedicamento({
    required this.fechaInicio,
    this.fechaFin,
    required this.medicamento,
    required this.dosis,
    required this.unidad,
    this.razonFin,
    List<CambioDosis>? cambiosDosis,
    this.efectosSecundarios,
    this.notasEficacia,
  }) : cambiosDosis = cambiosDosis ?? [];

  // Métodos auxiliares
  bool get estaActivo => fechaFin == null;

  Duration get duracionTratamiento {
    final fin = fechaFin ?? DateTime.now();
    return fin.difference(fechaInicio);
  }

  int get diasTratamiento {
    return duracionTratamiento.inDays;
  }

  bool tuvoModificaciones() {
    return cambiosDosis.isNotEmpty;
  }

  void agregarCambioDosis(CambioDosis cambio) {
    cambiosDosis.add(cambio);
    save(); // Guardar cambios en Hive
  }

  // Compatibility getters expected by UI code elsewhere in the app.
  // If these values are not present in this model version, we expose
  // conservative defaults so the app can still compile and run.
  int? get medicamentoKey => null;

  /// A human-readable type of the last change. Falls back to razonFin.
  String get tipoCambio => razonFin ?? '';

  /// When the UI asks for fechaCambio, use fechaInicio as a fallback.
  DateTime get fechaCambio => fechaInicio;

  Map<String, dynamic> toJson() {
    return {
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin?.toIso8601String(),
      'medicamento': medicamento,
      'dosis': dosis,
      'unidad': unidad,
      'razonFin': razonFin,
      'cambiosDosis': cambiosDosis.map((c) => c.toJson()).toList(),
      'efectosSecundarios': efectosSecundarios,
      'notasEficacia': notasEficacia,
    };
  }

  factory HistorialMedicamento.fromJson(Map<String, dynamic> json) {
    return HistorialMedicamento(
      fechaInicio: DateTime.parse(json['fechaInicio']),
      fechaFin: json['fechaFin'] != null
          ? DateTime.parse(json['fechaFin'])
          : null,
      medicamento: json['medicamento'],
      dosis: json['dosis'],
      unidad: json['unidad'],
      razonFin: json['razonFin'],
      cambiosDosis: (json['cambiosDosis'] as List)
          .map((c) => CambioDosis.fromJson(c))
          .toList(),
      efectosSecundarios: json['efectosSecundarios'],
      notasEficacia: json['notasEficacia'],
    );
  }
}
