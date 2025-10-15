// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Crisis.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CrisisAdapter extends TypeAdapter<Crisis> {
  @override
  final int typeId = 0;

  @override
  Crisis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Crisis(
      fechaHora: fields[0] as DateTime,
      duracion: fields[1] as String,
      consciente: fields[2] as String,
      medicamentoRescate: fields[3] as String,
      preictal: fields[4] as String?,
      ictal: fields[5] as String?,
      medicacionEmergencia: fields[6] as String?,
      postictalSentimiento: fields[7] as String?,
      postictalTiempoRecuperacion: fields[8] as String?,
      estadoAnimoAntes: fields[9] as int?,
      estadoAnimoDespues: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Crisis obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.fechaHora)
      ..writeByte(1)
      ..write(obj.duracion)
      ..writeByte(2)
      ..write(obj.consciente)
      ..writeByte(3)
      ..write(obj.medicamentoRescate)
      ..writeByte(4)
      ..write(obj.preictal)
      ..writeByte(5)
      ..write(obj.ictal)
      ..writeByte(6)
      ..write(obj.medicacionEmergencia)
      ..writeByte(7)
      ..write(obj.postictalSentimiento)
      ..writeByte(8)
      ..write(obj.postictalTiempoRecuperacion)
      ..writeByte(9)
      ..write(obj.estadoAnimoAntes)
      ..writeByte(10)
      ..write(obj.estadoAnimoDespues);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrisisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
