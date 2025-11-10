// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HistorialMedicamento.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistorialMedicamentoAdapter extends TypeAdapter<HistorialMedicamento> {
  @override
  final int typeId = 5;

  @override
  HistorialMedicamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistorialMedicamento(
      fechaInicio: fields[0] as DateTime,
      fechaFin: fields[1] as DateTime?,
      medicamento: fields[2] as String,
      dosis: fields[3] as String,
      unidad: fields[4] as String,
      razonFin: fields[5] as String?,
      cambiosDosis: (fields[6] as List?)?.cast<CambioDosis>(),
      efectosSecundarios: fields[7] as String?,
      notasEficacia: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HistorialMedicamento obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.fechaInicio)
      ..writeByte(1)
      ..write(obj.fechaFin)
      ..writeByte(2)
      ..write(obj.medicamento)
      ..writeByte(3)
      ..write(obj.dosis)
      ..writeByte(4)
      ..write(obj.unidad)
      ..writeByte(5)
      ..write(obj.razonFin)
      ..writeByte(6)
      ..write(obj.cambiosDosis)
      ..writeByte(7)
      ..write(obj.efectosSecundarios)
      ..writeByte(8)
      ..write(obj.notasEficacia);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistorialMedicamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
