// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TomaMedicamento.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TomaMedicamentoAdapter extends TypeAdapter<TomaMedicamento> {
  @override
  final int typeId = 2;

  @override
  TomaMedicamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TomaMedicamento(
      medicamentoKey: fields[0] as int,
      medicamentoNombre: fields[1] as String,
      fechaProgramada: fields[2] as DateTime,
      estado: fields[3] as String,
      fechaReal: fields[4] as DateTime?,
      razon: fields[5] as String?,
      retraso: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TomaMedicamento obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.medicamentoKey)
      ..writeByte(1)
      ..write(obj.medicamentoNombre)
      ..writeByte(2)
      ..write(obj.fechaProgramada)
      ..writeByte(3)
      ..write(obj.estado)
      ..writeByte(4)
      ..write(obj.fechaReal)
      ..writeByte(5)
      ..write(obj.razon)
      ..writeByte(6)
      ..write(obj.retraso);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TomaMedicamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
