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
  });
}
