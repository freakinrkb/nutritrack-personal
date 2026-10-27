import 'package:hive_ce_flutter/hive_flutter.dart';

part 'habit_dbo.g.dart';

/// A user-defined daily routine.
///
/// Habits are per-profile, like the diary. [sortOrder] keeps the order the
/// user created them in without relying on Hive key ordering.
@HiveType(typeId: 25)
class HabitDBO extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int sortOrder;

  @HiveField(3)
  DateTime createdAt;

  HabitDBO({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });
}
