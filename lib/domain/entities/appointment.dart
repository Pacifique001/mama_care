import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'appointment.g.dart';

enum AppointmentStatus { pending, confirmed, completed, cancelled ,rescheduled, scheduled}

@JsonSerializable(explicitToJson: true)
class Appointment extends Equatable {
  final String id;
  final String userId;
  final String doctorId;
  final DateTime requestedTime;
  final DateTime? scheduledTime;
  final AppointmentStatus status;
  final String? nurseId;
  final String reason;
  final String? notes;

  const Appointment({
    required this.id,
    required this.userId,
    required this.doctorId,
    required this.requestedTime,
    this.scheduledTime,
    required this.status,
    this.nurseId,
    required this.reason,
    this.notes,
  });

  // Add JSON serialization
  factory Appointment.fromJson(Map<String, dynamic> json) => 
      _$AppointmentFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentToJson(this);
   
 

  // Enhanced Firestore conversion
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      userId: data['userId'] as String,
      doctorId: data['doctorId'] as String,
      requestedTime: (data['requestedTime'] as Timestamp).toDate(),
      scheduledTime: data['scheduledTime']?.toDate(),
      status: _parseStatus(data['status'] as String),
      nurseId: data['nurseId'] as String?,
      reason: data['reason'] as String,
      notes: data['notes'] as String?,
    );
  }

  static AppointmentStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return AppointmentStatus.pending;
      case 'confirmed': return AppointmentStatus.confirmed;
      case 'completed': return AppointmentStatus.completed;
      case 'cancelled': return AppointmentStatus.cancelled;
      default: throw ArgumentError('Invalid status: $status');
    }
  }

  static Map<String, dynamic> toFirestore(Appointment appointment) {
    return {
      'userId': appointment.userId,
      'doctorId': appointment.doctorId,
      'requestedTime': Timestamp.fromDate(appointment.requestedTime),
      'scheduledTime': appointment.scheduledTime != null
          ? Timestamp.fromDate(appointment.scheduledTime!)
          : null,
      'status': statusToString(appointment.status),
      'nurseId': appointment.nurseId,
      'reason': appointment.reason,
      'notes': appointment.notes,
    };
  }

  static String statusToString(AppointmentStatus status) {
    return status.toString().split('.').last;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    doctorId,
    requestedTime,
    scheduledTime,
    status,
    nurseId,
    reason,
    notes,
  ];

  Appointment copyWith({
    String? id,
    String? userId,
    String? doctorId,
    DateTime? requestedTime,
    DateTime? scheduledTime,
    AppointmentStatus? status,
    String? nurseId,
    String? reason,
    String? notes,
  }) {
    return Appointment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      doctorId: doctorId ?? this.doctorId,
      requestedTime: requestedTime ?? this.requestedTime,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      nurseId: nurseId ?? this.nurseId,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
    );
  }


}