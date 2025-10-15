import 'package:hive/hive.dart';

part 'Crisis.g.dart';

@HiveType(typeId: 0)
class Crisis extends HiveObject {
  // Fecha y hora de la crisis
  @HiveField(0)
  DateTime fechaHora;

  // Registro rápido
  @HiveField(1)
  String duracion;

  @HiveField(2)
  String consciente;

  @HiveField(3)
  String medicamentoRescate;

  // Detalles opcionales
  @HiveField(4)
  String? preictal;

  @HiveField(5)
  String? ictal;

  @HiveField(6)
  String? medicacionEmergencia;

  @HiveField(7)
  String? postictalSentimiento;

  @HiveField(8)
  String? postictalTiempoRecuperacion;

  // 1 = Triste 😞, 2 = Neutral 😐, 3 = Feliz 🙂
  @HiveField(9)
  int? estadoAnimoAntes;

  @HiveField(10)
  int? estadoAnimoDespues;

  Crisis({
    required this.fechaHora,
    required this.duracion,
    required this.consciente,
    required this.medicamentoRescate,
    this.preictal,
    this.ictal,
    this.medicacionEmergencia,
    this.postictalSentimiento,
    this.postictalTiempoRecuperacion,
    this.estadoAnimoAntes,
    this.estadoAnimoDespues,
  });
}
