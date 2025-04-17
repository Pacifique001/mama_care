// lib/domain/entities/nurse_assignment.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'nurse_assignment.g.dart'; // If using json_serializable

@JsonSerializable()
class NurseAssignment extends Equatable {
  final String id; // ID of this specific assignment document
  final String nurseId; // ID of the assigned nurse
  final String patientId; // ID of the assigned patient
  final String doctorId; // ID of the assigning doctor
  final DateTime assignedAt; // Timestamp of assignment

  // Optional fields you might add:
  // final String? notes;
  // final bool? isActive; // To mark if assignment is current

  const NurseAssignment({
    required this.id,
    required this.nurseId,
    required this.patientId,
    required this.doctorId,
    required this.assignedAt,
  });

  @override
  List<Object?> get props => [id, nurseId, patientId, doctorId, assignedAt];

  // --- JSON/Firestore Conversion ---
  factory NurseAssignment.fromJson(Map<String, dynamic> json) =>
      _$NurseAssignmentFromJson(json); // If using json_serializable
  Map<String, dynamic> toJson() => _$NurseAssignmentToJson(this); // If using json_serializable


  // Example Firestore conversion
  factory NurseAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NurseAssignment(
      id: doc.id,
      nurseId: data['nurseId'] as String? ?? '',
      patientId: data['patientId'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      assignedAt: (data['assignedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  get nurse => [id, nurseId, patientId, doctorId, assignedAt];

   Map<String, dynamic> toFirestoreMap() {
     return {
       'nurseId': nurseId,
       'patientId': patientId,
       'doctorId': doctorId,
       'assignedAt': Timestamp.fromDate(assignedAt),
     };
   }
}