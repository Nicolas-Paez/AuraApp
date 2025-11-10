// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Medicamento.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicamentoAdapter extends TypeAdapter<Medicamento> {
  @override
  final int typeId = 1;

  @override
  Medicamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medicamento(
      nombre: fields[0] as String,
      dosis: fields[1] as double,
      unidad: fields[2] as String,
      horarios: (fields[3] as List).cast<String>(),
      notas: fields[4] as String?,
      esRescate: fields[5] as bool,
      fechaInicio: fields[6] as DateTime,
      adherencia: fields[7] as double?,
      alertas: fields[8] as String?,
      dosisInicial: fields[9] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Medicamento obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.nombre)
      ..writeByte(1)
      ..write(obj.dosis)
      ..writeByte(2)
      ..write(obj.unidad)
      ..writeByte(3)
      ..write(obj.horarios)
      ..writeByte(4)
      ..write(obj.notas)
      ..writeByte(5)
      ..write(obj.esRescate)
      ..writeByte(6)
      ..write(obj.fechaInicio)
      ..writeByte(7)
      ..write(obj.adherencia)
      ..writeByte(8)
      ..write(obj.alertas)
      ..writeByte(9)
      ..write(obj.dosisInicial);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
