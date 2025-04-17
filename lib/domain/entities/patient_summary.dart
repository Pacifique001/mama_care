// lib/domain/entities/patient_summary.dart

import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore conversion example

/// Represents essential patient information for display in lists.
class PatientSummary extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final DateTime? dueDate; // Example extra field

  const PatientSummary({
    required this.id,
    required this.name,
    this.imageUrl,
    this.dueDate,
  });

  @override
  List<Object?> get props => [id, name, imageUrl, dueDate];

  // Example factory for converting from a full Patient/User entity
   factory PatientSummary.fromPatient(PatientSummary patient) {
     return PatientSummary(
      id: patient.id,
       name: patient.name,
       imageUrl: patient.imageUrl,
       dueDate: patient.dueDate,
      );
    }

  // Example factory from Firestore data (adapt to your patient document structure)
  factory PatientSummary.fromFirestore(DocumentSnapshot doc) {
     final data = doc.data() as Map<String, dynamic>? ?? {};
     return PatientSummary(
       id: doc.id,
       name: data['name'] as String? ?? 'Unknown Patient',
       imageUrl: data['profileImageUrl'] as String?, // Assuming field name in Firestore
       dueDate: (data['dueDate'] as Timestamp?)?.toDate(), // Assuming field name
     );
  }
}