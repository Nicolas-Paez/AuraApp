// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'EstadoAnimico.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EstadoAnimicoAdapter extends TypeAdapter<EstadoAnimico> {
  @override
  final int typeId = 4;

  @override
  EstadoAnimico read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EstadoAnimico(
      fecha: fields[0] as DateTime,
      nivelAnimo: fields[1] as int,
      nivelAnsiedad: fields[2] as int,
      nivelIrritabilidad: fields[3] as int,
      sintomas: (fields[4] as List).cast<String>(),
      notas: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EstadoAnimico obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.fecha)
      ..writeByte(1)
      ..write(obj.nivelAnimo)
      ..writeByte(2)
      ..write(obj.nivelAnsiedad)
      ..writeByte(3)
      ..write(obj.nivelIrritabilidad)
      ..writeByte(4)
      ..write(obj.sintomas)
      ..writeByte(5)
      ..write(obj.notas);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EstadoAnimicoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
