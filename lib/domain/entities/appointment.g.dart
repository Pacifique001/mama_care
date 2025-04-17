// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Appointment _$AppointmentFromJson(Map<String, dynamic> json) => Appointment(
  id: json['id'] as String,
  userId: json['userId'] as String,
  doctorId: json['doctorId'] as String,
  requestedTime: DateTime.parse(json['requestedTime'] as String),
  scheduledTime:
      json['scheduledTime'] == null
          ? null
          : DateTime.parse(json['scheduledTime'] as String),
  status: $enumDecode(_$AppointmentStatusEnumMap, json['status']),
  nurseId: json['nurseId'] as String?,
  reason: json['reason'] as String,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$AppointmentToJson(Appointment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'doctorId': instance.doctorId,
      'requestedTime': instance.requestedTime.toIso8601String(),
      'scheduledTime': instance.scheduledTime?.toIso8601String(),
      'status': _$AppointmentStatusEnumMap[instance.status]!,
      'nurseId': instance.nurseId,
      'reason': instance.reason,
      'notes': instance.notes,
    };

const _$AppointmentStatusEnumMap = {
  AppointmentStatus.pending: 'pending',
  AppointmentStatus.confirmed: 'confirmed',
  AppointmentStatus.completed: 'completed',
  AppointmentStatus.cancelled: 'cancelled',
  AppointmentStatus.rescheduled: 'rescheduled',
  AppointmentStatus.scheduled: 'scheduled',
};
