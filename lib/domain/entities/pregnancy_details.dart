import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'pregnancy_details.g.dart';

@JsonSerializable()
class PregnancyDetails {
  final String? userId;
  final int? startingDay; // Store as milliseconds since epoch
  final int? weeksPregnant;
  final int? daysPregnant;
  final double? babyHeight;
  final double? babyWeight;
  final DateTime? dueDate;

  PregnancyDetails({
    required this.userId,
    required this.startingDay,
    required this.weeksPregnant,
    required this.daysPregnant,
    required this.babyHeight,
    required this.babyWeight,
    required this.dueDate,
  });

  factory PregnancyDetails.fromJson(Map<String, dynamic> json) {
    return PregnancyDetails(
      userId: json['userId'],
      startingDay: json['startingDay'],
      weeksPregnant: json['weeksPregnant'],
      daysPregnant: json['daysPregnant'],
      babyHeight: json['babyHeight'],
      babyWeight: json['babyWeight'],
      dueDate: DateTime.parse(json['dueDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'startingDay': startingDay,
      'weeksPregnant': weeksPregnant,
      'daysPregnant': daysPregnant,
      'babyHeight': babyHeight,
      'babyWeight': babyWeight,
      'dueDate': dueDate?.toIso8601String(),
    };
  }
}
