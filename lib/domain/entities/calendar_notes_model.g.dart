// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_notes_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CalendarNotesModel _$CalendarNotesModelFromJson(
  Map<String, dynamic> json,
) => CalendarNotesModel(
  date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
  notes:
      (json['notes'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
);

Map<String, dynamic> _$CalendarNotesModelToJson(CalendarNotesModel instance) =>
    <String, dynamic>{
      'date': instance.date?.toIso8601String(),
      'notes': instance.notes,
    };
