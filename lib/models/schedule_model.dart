import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ShiftType { morning, afternoon, evening, off }

extension ShiftTypeExtension on ShiftType {
  String get label {
    switch (this) {
      case ShiftType.morning:
        return 'Ca sáng';
      case ShiftType.afternoon:
        return 'Ca chiều';
      case ShiftType.evening:
        return 'Ca tối';
      case ShiftType.off:
        return 'Nghỉ';
    }
  }

  String get value {
    switch (this) {
      case ShiftType.morning:
        return 'morning';
      case ShiftType.afternoon:
        return 'afternoon';
      case ShiftType.evening:
        return 'evening';
      case ShiftType.off:
        return 'off';
    }
  }

  String get timeRange {
    switch (this) {
      case ShiftType.morning:
        return '06:00 - 14:00';
      case ShiftType.afternoon:
        return '14:00 - 22:00';
      case ShiftType.evening:
        return '22:00 - 06:00';
      case ShiftType.off:
        return '';
    }
  }

  static ShiftType fromString(String? value) {
    switch (value) {
      case 'morning':
        return ShiftType.morning;
      case 'afternoon':
        return ShiftType.afternoon;
      case 'evening':
        return ShiftType.evening;
      case 'off':
      default:
        return ShiftType.off;
    }
  }
}

class DaySchedule {
  final ShiftType monday;
  final ShiftType tuesday;
  final ShiftType wednesday;
  final ShiftType thursday;
  final ShiftType friday;
  final ShiftType saturday;
  final ShiftType sunday;

  const DaySchedule({
    this.monday = ShiftType.off,
    this.tuesday = ShiftType.off,
    this.wednesday = ShiftType.off,
    this.thursday = ShiftType.off,
    this.friday = ShiftType.off,
    this.saturday = ShiftType.off,
    this.sunday = ShiftType.off,
  });

  factory DaySchedule.allOff() => const DaySchedule();

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      monday: ShiftTypeExtension.fromString(json['monday'] as String?),
      tuesday: ShiftTypeExtension.fromString(json['tuesday'] as String?),
      wednesday: ShiftTypeExtension.fromString(json['wednesday'] as String?),
      thursday: ShiftTypeExtension.fromString(json['thursday'] as String?),
      friday: ShiftTypeExtension.fromString(json['friday'] as String?),
      saturday: ShiftTypeExtension.fromString(json['saturday'] as String?),
      sunday: ShiftTypeExtension.fromString(json['sunday'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday.value,
      'tuesday': tuesday.value,
      'wednesday': wednesday.value,
      'thursday': thursday.value,
      'friday': friday.value,
      'saturday': saturday.value,
      'sunday': sunday.value,
    };
  }

  ShiftType shiftForDay(int weekday) {
    // weekday: 1 = Monday, 7 = Sunday
    switch (weekday) {
      case 1:
        return monday;
      case 2:
        return tuesday;
      case 3:
        return wednesday;
      case 4:
        return thursday;
      case 5:
        return friday;
      case 6:
        return saturday;
      case 7:
        return sunday;
      default:
        return ShiftType.off;
    }
  }

  DaySchedule copyWith({
    ShiftType? monday,
    ShiftType? tuesday,
    ShiftType? wednesday,
    ShiftType? thursday,
    ShiftType? friday,
    ShiftType? saturday,
    ShiftType? sunday,
  }) {
    return DaySchedule(
      monday: monday ?? this.monday,
      tuesday: tuesday ?? this.tuesday,
      wednesday: wednesday ?? this.wednesday,
      thursday: thursday ?? this.thursday,
      friday: friday ?? this.friday,
      saturday: saturday ?? this.saturday,
      sunday: sunday ?? this.sunday,
    );
  }

  int get workingDays {
    final days = [
      monday,
      tuesday,
      wednesday,
      thursday,
      friday,
      saturday,
      sunday
    ];
    return days.where((s) => s != ShiftType.off).length;
  }
}

class ScheduleModel extends Equatable {
  final String id;
  final String storeId;
  final String weekStart; // YYYY-MM-DD (Monday of the week)
  final Map<String, DaySchedule> shifts; // userId → DaySchedule

  const ScheduleModel({
    required this.id,
    required this.storeId,
    required this.weekStart,
    required this.shifts,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json, String id) {
    final shiftsData = json['shifts'] as Map<String, dynamic>? ?? {};
    final parsedShifts = <String, DaySchedule>{};
    for (final entry in shiftsData.entries) {
      if (entry.value is Map<String, dynamic>) {
        parsedShifts[entry.key] =
            DaySchedule.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return ScheduleModel(
      id: id,
      storeId: json['storeId'] as String? ?? '',
      weekStart: json['weekStart'] as String? ?? '',
      shifts: parsedShifts,
    );
  }

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleModel.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'weekStart': weekStart,
      'shifts': shifts.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  ScheduleModel copyWith({
    String? id,
    String? storeId,
    String? weekStart,
    Map<String, DaySchedule>? shifts,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      weekStart: weekStart ?? this.weekStart,
      shifts: shifts ?? Map.from(this.shifts),
    );
  }

  ScheduleModel withUserShift(String userId, DaySchedule schedule) {
    final updated = Map<String, DaySchedule>.from(shifts);
    updated[userId] = schedule;
    return copyWith(shifts: updated);
  }

  DaySchedule? getScheduleForUser(String userId) => shifts[userId];

  @override
  List<Object?> get props => [id, storeId, weekStart, shifts];

  @override
  String toString() =>
      'ScheduleModel(id: $id, storeId: $storeId, weekStart: $weekStart, members: ${shifts.length})';
}
