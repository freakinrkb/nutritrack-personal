// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_checkin_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitCheckinDBOAdapter extends TypeAdapter<HabitCheckinDBO> {
  @override
  final typeId = 26;

  @override
  HabitCheckinDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitCheckinDBO(
      habitId: fields[0] as String,
      dayKey: fields[1] as String,
      status: (fields[2] as num).toInt(),
      recordedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HabitCheckinDBO obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.habitId)
      ..writeByte(1)
      ..write(obj.dayKey)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.recordedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitCheckinDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
