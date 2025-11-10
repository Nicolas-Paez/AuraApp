import 'package:hive/hive.dart';

part 'Medicamento.g.dart';

@HiveType(typeId: 1)
class Medicamento extends HiveObject {
  @HiveField(0)
  String nombre;

  // ahora dosis es numérica
  @HiveField(1)
  double dosis;

  // unidad: "mg", "ml", "pastilla(s)"
  @HiveField(2)
  String unidad;

  // múltiples horarios guardados como strings "HH:mm"
  @HiveField(3)
  List<String> horarios;

  @HiveField(4)
  String? notas;

  @HiveField(5)
  bool esRescate;

  @HiveField(6)
  DateTime fechaInicio;

  @HiveField(7)
  double? adherencia;

  @HiveField(8)
  String? alertas;

  // Dosis inicial del tratamiento (opcional). Se usa para mostrar el punto
  // inicial en los gráficos de historial farmacológico. Si es null, el UI
  // hará fallback a `dosis`.
  @HiveField(9)
  double? dosisInicial;

  // Compatibility getter: some utilities check `med.activo` — expose a default
  // active flag. For a more accurate check, consider computing this from a
  // HistorialMedicamento or adding a persisted field.
  bool get activo => true;

  Medicamento({
    required this.nombre,
    required this.dosis,
    required this.unidad,
    required this.horarios,
    this.notas,
    this.esRescate = false,
    required this.fechaInicio,
    this.adherencia,
    this.alertas,
    this.dosisInicial,
  });
}
