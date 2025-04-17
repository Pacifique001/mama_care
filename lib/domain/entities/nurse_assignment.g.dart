// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nurse_assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NurseAssignment _$NurseAssignmentFromJson(Map<String, dynamic> json) =>
    NurseAssignment(
      id: json['id'] as String,
      nurseId: json['nurseId'] as String,
      patientId: json['patientId'] as String,
      doctorId: json['doctorId'] as String,
      assignedAt: DateTime.parse(json['assignedAt'] as String),
    );

Map<String, dynamic> _$NurseAssignmentToJson(NurseAssignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nurseId': instance.nurseId,
      'patientId': instance.patientId,
      'doctorId': instance.doctorId,
      'assignedAt': instance.assignedAt.toIso8601String(),
    };
