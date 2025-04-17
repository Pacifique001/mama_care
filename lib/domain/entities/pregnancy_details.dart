import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'pregnancy_details.g.dart';

@JsonSerializable(explicitToJson: true)
class PregnancyDetails extends Equatable {
  final String? userId;
  final int startingDay;
  final int weeksPregnant;
  final int daysPregnant;
  final double babyHeight;
  final double babyWeight;
  
  @JsonKey(
    name: 'dueDate',
    fromJson: _fromJsonDate,
    toJson: _toJsonDate,
  )
  final DateTime dueDate;

  const PregnancyDetails({
    required this.userId,
    required this.startingDay,
    required this.weeksPregnant,
    required this.daysPregnant,
    required this.babyHeight,
    required this.babyWeight,
    required this.dueDate,
  });

  // Date conversion methods
  static DateTime _fromJsonDate(int milliseconds) => 
      DateTime.fromMillisecondsSinceEpoch(milliseconds);
      
  static int _toJsonDate(DateTime date) => date.millisecondsSinceEpoch;

  // Calculated properties
  DateTime get startDate => DateTime.fromMillisecondsSinceEpoch(startingDay);
  int get currentWeek => weeksPregnant;
  int get totalDaysPregnant => daysPregnant + (weeksPregnant * 7);
  DateTime get estimatedConceptionDate => dueDate.subtract(const Duration(days: 280));

  // JSON Serialization
  factory PregnancyDetails.fromJson(Map<String, dynamic> json) => 
      _$PregnancyDetailsFromJson(json);

  Map<String, dynamic> toJson(userId) => _$PregnancyDetailsToJson(this);

  // Copy with method
  PregnancyDetails copyWith({
    String? userId,
    int? startingDay,
    int? weeksPregnant,
    int? daysPregnant,
    double? babyHeight,
    double? babyWeight,
    DateTime? dueDate,
  }) {
    return PregnancyDetails(
      userId: userId ?? this.userId,
      startingDay: startingDay ?? this.startingDay,
      weeksPregnant: weeksPregnant ?? this.weeksPregnant,
      daysPregnant: daysPregnant ?? this.daysPregnant,
      babyHeight: babyHeight ?? this.babyHeight,
      babyWeight: babyWeight ?? this.babyWeight,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    startingDay,
    weeksPregnant,
    daysPregnant,
    babyHeight,
    babyWeight,
    dueDate,
  ];

  get daysRemaining => null;
}