import 'package:hive_ce_flutter/hive_flutter.dart';

part 'habit_checkin_dbo.g.dart';

/// One habit's status for one logical day.
///
/// The Hive key is [keyFor] rather than a separate id: a habit can have at
/// most one status per day, so `(habitId, dayKey)` is the natural identity and
/// makes an upsert a single `put`.
@HiveType(typeId: 26)
class HabitCheckinDBO extends HiveObject {
  static const int doneStatus = 0;
  static const int skippedStatus = 1;

  @HiveField(0)
  String habitId;

  /// The logical day as `yyyy-MM-dd`, resolved through the user's configured
  /// day boundary when the status is written.
  @HiveField(1)
  String dayKey;

  /// One of [doneStatus] or [skippedStatus].
  @HiveField(2)
  int status;

  @HiveField(3)
  DateTime recordedAt;

  HabitCheckinDBO({
    required this.habitId,
    required this.dayKey,
    required this.status,
    required this.recordedAt,
  });

  static String keyFor(String habitId, String dayKey) => '$habitId|$dayKey';
}
