// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pregnancy_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PregnancyDetails _$PregnancyDetailsFromJson(Map<String, dynamic> json) =>
    PregnancyDetails(
      userId: json['userId'] as String?,
      startingDay: (json['startingDay'] as num?)?.toInt(),
      weeksPregnant: (json['weeksPregnant'] as num?)?.toInt(),
      daysPregnant: (json['daysPregnant'] as num?)?.toInt(),
      babyHeight: (json['babyHeight'] as num?)?.toDouble(),
      babyWeight: (json['babyWeight'] as num?)?.toDouble(),
      dueDate:
          json['dueDate'] == null
              ? null
              : DateTime.parse(json['dueDate'] as String),
    );

Map<String, dynamic> _$PregnancyDetailsToJson(PregnancyDetails instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'startingDay': instance.startingDay,
      'weeksPregnant': instance.weeksPregnant,
      'daysPregnant': instance.daysPregnant,
      'babyHeight': instance.babyHeight,
      'babyWeight': instance.babyWeight,
      'dueDate': instance.dueDate?.toIso8601String(),
    };
