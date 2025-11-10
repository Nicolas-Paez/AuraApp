// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'CambioDosis.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CambioDosisAdapter extends TypeAdapter<CambioDosis> {
  @override
  final int typeId = 3;

  @override
  CambioDosis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CambioDosis(
      fecha: fields[0] as DateTime,
      dosis: fields[1] as String,
      razon: fields[2] as String,
      unidad: fields[3] as String,
      medicamentoKey: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CambioDosis obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.fecha)
      ..writeByte(1)
      ..write(obj.dosis)
      ..writeByte(2)
      ..write(obj.razon)
      ..writeByte(3)
      ..write(obj.unidad)
      ..writeByte(4)
      ..write(obj.medicamentoKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CambioDosisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
