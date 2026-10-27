import 'package:equatable/equatable.dart';

enum HabitStatus { done, skipped }

class HabitEntity extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  final DateTime createdAt;

  const HabitEntity({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  HabitEntity copyWith({String? name, int? sortOrder}) => HabitEntity(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, name, sortOrder, createdAt];
}

class HabitCheckinEntity extends Equatable {
  final String habitId;
  final String dayKey;
  final HabitStatus status;
  final DateTime recordedAt;

  const HabitCheckinEntity({
    required this.habitId,
    required this.dayKey,
    required this.status,
    required this.recordedAt,
  });

  @override
  List<Object?> get props => [habitId, dayKey, status, recordedAt];
}

/// A habit plus its state for the logical day the Home card is showing.
class RoutineHabitEntity extends Equatable {
  final HabitEntity habit;
  final HabitStatus? status;
  final int streak;

  const RoutineHabitEntity({
    required this.habit,
    required this.status,
    required this.streak,
  });

  bool get isDone => status == HabitStatus.done;
  bool get isSkipped => status == HabitStatus.skipped;

  @override
  List<Object?> get props => [habit, status, streak];
}

class RoutineDayEntity extends Equatable {
  final DateTime day;
  final List<RoutineHabitEntity> habits;

  const RoutineDayEntity({required this.day, required this.habits});

  int get doneCount => habits.where((habit) => habit.isDone).length;
  int get totalCount => habits.length;
  bool get isEmpty => habits.isEmpty;

  @override
  List<Object?> get props => [day, habits];
}
