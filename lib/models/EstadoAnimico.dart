import 'package:hive/hive.dart';
part 'EstadoAnimico.g.dart';

@HiveType(typeId: 4)
class EstadoAnimico extends HiveObject {
  @HiveField(0)
  final DateTime fecha;

  @HiveField(1)
  final int nivelAnimo; // 1-5

  @HiveField(2)
  final int nivelAnsiedad; // 1-5

  @HiveField(3)
  final int nivelIrritabilidad; // 1-5

  @HiveField(4)
  final List<String> sintomas;

  @HiveField(5)
  final String? notas;

  EstadoAnimico({
    required this.fecha,
    required this.nivelAnimo,
    required this.nivelAnsiedad,
    required this.nivelIrritabilidad,
    required this.sintomas,
    this.notas,
  });

  // Métodos auxiliares para calcular promedios/estadísticas
  double get promedioEstado {
    return (nivelAnimo + nivelAnsiedad + nivelIrritabilidad) / 3;
  }

  bool tieneSintoma(String sintoma) {
    return sintomas.contains(sintoma);
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': fecha.toIso8601String(),
      'nivelAnimo': nivelAnimo,
      'nivelAnsiedad': nivelAnsiedad,
      'nivelIrritabilidad': nivelIrritabilidad,
      'sintomas': sintomas,
      'notas': notas,
    };
  }

  factory EstadoAnimico.fromJson(Map<String, dynamic> json) {
    return EstadoAnimico(
      fecha: DateTime.parse(json['fecha']),
      nivelAnimo: json['nivelAnimo'],
      nivelAnsiedad: json['nivelAnsiedad'],
      nivelIrritabilidad: json['nivelIrritabilidad'],
      sintomas: List<String>.from(json['sintomas']),
      notas: json['notas'],
    );
  }
}
