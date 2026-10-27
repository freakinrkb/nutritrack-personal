// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitDBOAdapter extends TypeAdapter<HabitDBO> {
  @override
  final typeId = 25;

  @override
  HabitDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitDBO(
      id: fields[0] as String,
      name: fields[1] as String,
      sortOrder: (fields[2] as num).toInt(),
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HabitDBO obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sortOrder)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
