import 'package:hive/hive.dart';

part 'TomaMedicamento.g.dart';

@HiveType(typeId: 2)
class TomaMedicamento extends HiveObject {
  @HiveField(0)
  int medicamentoKey;

  @HiveField(1)
  String medicamentoNombre;

  @HiveField(2)
  DateTime fechaProgramada;

  @HiveField(3)
  String estado; // 'Pendiente', 'Tomada', 'No tomada'

  @HiveField(4)
  DateTime? fechaReal;

  @HiveField(5)
  String? razon;

  @HiveField(6)
  int? retraso; // minutos de diferencia entre programada y real

  TomaMedicamento({
    required this.medicamentoKey,
    required this.medicamentoNombre,
    required this.fechaProgramada,
    required this.estado,
    this.fechaReal,
    this.razon,
    this.retraso,
  });
}
