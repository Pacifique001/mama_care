// lib/data/repositories/appointment_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Use custom exceptions
import 'package:mama_care/data/repositories/appointment_repository.dart'; // Import interface
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/nurse_assignment.dart';
import 'package:uuid/uuid.dart'; // Use Uuid for generating IDs

@Injectable(as: AppointmentRepository) // Bind implementation to interface
class AppointmentRepositoryImpl implements AppointmentRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;
  final Uuid _uuid; // Inject Uuid

  // Collection references
  late final CollectionReference _appointmentsCollection = _firestore.collection('appointments');
  late final CollectionReference _nurseAssignmentsCollection = _firestore.collection('nurse_assignments');

  AppointmentRepositoryImpl(this._firestore, this._logger, this._uuid);

  // --- Appointment Methods ---

  @override
  Future<List<Appointment>> getUserAppointments(String userId) async {
    _logger.d("Repo: Fetching appointments for user $userId");
    if (userId.isEmpty) return [];
    try {
      final snapshot = await _appointmentsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('requestedTime', descending: true)
          .get();

      final appointments = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
      _logger.i("Repo: Fetched ${appointments.length} appointments for user $userId.");
      return appointments;
    } on FirebaseException catch (e, stackTrace) {
      _logger.e("Repo: Firestore error fetching user appointments for $userId", error: e, stackTrace: stackTrace);
      throw ApiException('Failed to load your appointments.', statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
      _logger.e("Repo: Error fetching user appointments for $userId", error: e, stackTrace: stackTrace);
      throw DataProcessingException('Could not process appointment data.', cause: e);
    }
  }

  @override
  Stream<List<Appointment>> getDoctorAppointments(String doctorId) {
    _logger.d("Repo: Setting up appointment stream for doctor $doctorId");
     if (doctorId.isEmpty) return Stream.value([]);
    try {
        return _appointmentsCollection
            .where('doctorId', isEqualTo: doctorId)
            .orderBy('requestedTime', descending: false) // Show upcoming first
            .snapshots()
            .map((snapshot) {
                final appointments = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
                _logger.f("Repo: Doctor appointment stream update: ${appointments.length} items.");
                return appointments;
            })
            .handleError((error, stackTrace) {
                _logger.e("Repo: Error in doctor appointment stream for $doctorId", error: error, stackTrace: stackTrace);
                // Propagate as an error in the stream
                throw ApiException("Error listening to doctor appointments.", cause: error);
            });
    } catch (e, stackTrace) {
       _logger.e("Repo: Failed to set up doctor appointment stream for $doctorId", error: e, stackTrace: stackTrace);
       return Stream.error(ApiException("Could not get doctor appointments.", cause: e));
    }
  }

  @override
  Stream<List<Appointment>> getNurseUpcomingAppointments(String nurseId) {
     _logger.d("Repo: Setting up upcoming appointment stream for nurse $nurseId");
      if (nurseId.isEmpty) return Stream.value([]);
     try {
         final now = Timestamp.now();
         // Use Appointment.statusToString for query values
         final relevantStatuses = [
             Appointment.statusToString(AppointmentStatus.confirmed),
             Appointment.statusToString(AppointmentStatus.scheduled),
             Appointment.statusToString(AppointmentStatus.rescheduled)
         ];

         return _appointmentsCollection
             .where('nurseId', isEqualTo: nurseId)
             .where('status', whereIn: relevantStatuses) // Use status strings
             .where('requestedTime', isGreaterThanOrEqualTo: now) // Ensure requestedTime is used for filtering future
             .orderBy('requestedTime', descending: false)
             .snapshots()
             .map((snapshot) {
                 final appointments = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
                  _logger.f("Repo: Nurse upcoming appointment stream update: ${appointments.length} items.");
                 return appointments;
             })
             .handleError((error, stackTrace) {
                  _logger.e("Repo: Error in nurse upcoming appointment stream for $nurseId", error: error, stackTrace: stackTrace);
                 throw ApiException("Error listening to nurse appointments.", cause: error);
             });
      } catch (e, stackTrace) {
         _logger.e("Repo: Failed to set up nurse upcoming appointment stream for $nurseId", error: e, stackTrace: stackTrace);
         return Stream.error(ApiException("Could not get nurse appointments.", cause: e));
      }
  }


  @override
  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    _logger.i("Repo: Updating appointment $appointmentId status to ${status.name}");
     if (appointmentId.isEmpty) throw ArgumentError("Appointment ID required.");
    try {
      await _appointmentsCollection.doc(appointmentId).update({
          'status': Appointment.statusToString(status), // Use helper to convert enum
          'lastUpdated': FieldValue.serverTimestamp(), // Track update
      });
       _logger.d("Repo: Appointment $appointmentId status updated successfully.");
    } on FirebaseException catch (e, stackTrace) {
       _logger.e("Repo: Firestore error updating status for $appointmentId", error: e, stackTrace: stackTrace);
      throw ApiException('Failed to update appointment status.', statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
       _logger.e("Repo: Error updating status for $appointmentId", error: e, stackTrace: stackTrace);
      throw DataProcessingException('Could not update appointment status.', cause: e);
    }
  }

 @override
  Future<void> rescheduleAppointment(String appointmentId, DateTime newTime) async {
     _logger.i("Repo: Rescheduling appointment $appointmentId to $newTime");
      if (appointmentId.isEmpty) throw ArgumentError("Appointment ID required.");
    try {
      await _appointmentsCollection.doc(appointmentId).update({
        'scheduledTime': Timestamp.fromDate(newTime),
         // --- CORRECTED: Call static method using Class Name ---
        'status': Appointment.statusToString(AppointmentStatus.rescheduled), // Use Appointment.statusToString()
        'lastUpdated': FieldValue.serverTimestamp(),
      });
       _logger.d("Repo: Appointment $appointmentId rescheduled successfully.");
    } on FirebaseException catch (e, stackTrace) {
       _logger.e("Repo: Firestore error rescheduling appointment $appointmentId", error: e, stackTrace: stackTrace);
       throw ApiException('Failed to reschedule appointment.', statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
        _logger.e("Repo: Error rescheduling appointment $appointmentId", error: e, stackTrace: stackTrace);
       throw DataProcessingException('Could not reschedule appointment.', cause: e);
    }
  }

  @override
  Future<void> assignNurseToAppointment(String appointmentId, String nurseId) async {
     _logger.i("Repo: Assigning nurse $nurseId to appointment $appointmentId");
      if (appointmentId.isEmpty || nurseId.isEmpty) throw ArgumentError("Appointment and Nurse IDs required.");
    try {
      await _appointmentsCollection.doc(appointmentId).update({
          'nurseId': nurseId, // Assign the nurse ID
          'lastUpdated': FieldValue.serverTimestamp(),
       });
        _logger.d("Repo: Nurse $nurseId assigned to appointment $appointmentId successfully.");
        // Note: This does NOT update the Nurse's patient load. That should be handled
        // when a separate NurseAssignment record is created or via a Cloud Function trigger.
    } on FirebaseException catch (e, stackTrace) {
       _logger.e("Repo: Firestore error assigning nurse to appointment $appointmentId", error: e, stackTrace: stackTrace);
       throw ApiException('Failed to assign nurse to appointment.', statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
         _logger.e("Repo: Error assigning nurse to appointment $appointmentId", error: e, stackTrace: stackTrace);
        throw DataProcessingException('Could not assign nurse.', cause: e);
    }
  }

@override
  Future<Appointment> addAppointment(Appointment appointment) async {
     _logger.i("Repo: Adding new appointment ${appointment.id}");
      final docRef = _appointmentsCollection.doc(appointment.id);
     try {
        // --- CORRECTED: Call static method using Class Name ---
        // Use the static toFirestore helper method defined in Appointment
        await docRef.set(Appointment.toFirestore(appointment));
        _logger.i("Repo: Appointment ${appointment.id} added successfully.");
        return appointment;
     } on FirebaseException catch (e, stackTrace) {
        _logger.e("Repo: Firestore error adding appointment ${appointment.id}", error: e, stackTrace: stackTrace);
        throw ApiException('Failed to save appointment.', statusCode: e.code.hashCode, cause: e);
     } catch (e, stackTrace) {
         _logger.e("Repo: Error adding appointment ${appointment.id}", error: e, stackTrace: stackTrace);
         throw DataProcessingException('Could not save appointment.', cause: e);
     }
  }

  // --- Nurse Assignment Methods ---

  @override
  Stream<List<NurseAssignment>> getNurseAssignments(String doctorId) {
     _logger.d("Repo: Setting up nurse assignment stream for doctor $doctorId");
      if (doctorId.isEmpty) return Stream.value([]);
      try {
         return _nurseAssignmentsCollection
             .where('doctorId', isEqualTo: doctorId)
             .orderBy('assignedAt', descending: true)
             .snapshots()
             .map((snapshot) {
                 final assignments = snapshot.docs.map((doc) => NurseAssignment.fromFirestore(doc)).toList();
                 _logger.f("Repo: Nurse assignment stream update: ${assignments.length} items.");
                 return assignments;
              })
             .handleError((error, stackTrace) {
                 _logger.e("Repo: Error in nurse assignment stream for doctor $doctorId", error: error, stackTrace: stackTrace);
                 throw ApiException("Error listening to nurse assignments.", cause: error);
             });
      } catch (e, stackTrace) {
          _logger.e("Repo: Failed to set up nurse assignment stream for doctor $doctorId", error: e, stackTrace: stackTrace);
          return Stream.error(ApiException("Could not get nurse assignments.", cause: e));
      }
  }

  @override
  Future<void> assignPatientToNurse({ // Implementation uses named parameters now
    required String nurseId,
    required String patientId,
    required String doctorId,
  }) async {
     _logger.i("Repo: Creating assignment record for nurse $nurseId / patient $patientId");
     // Creates the LINK document. Assumes Nurse/Patient docs updated elsewhere (e.g., NurseRepo)
     if (nurseId.isEmpty || patientId.isEmpty || doctorId.isEmpty) {
         throw ArgumentError("Nurse, Patient, and Doctor IDs are required.");
     }
     try {
       final assignmentId = _uuid.v4(); // Generate unique ID for the assignment document
       final newAssignment = NurseAssignment(
          id: assignmentId,
          nurseId: nurseId,
          patientId: patientId,
          doctorId: doctorId,
          assignedAt: DateTime.now() // Use local time; Firestore timestamp added on write
       );
       // Use toFirestoreMap if NurseAssignment has it, otherwise toJson
       await _nurseAssignmentsCollection.doc(assignmentId).set(newAssignment.toFirestoreMap());
        _logger.i("Repo: Nurse assignment record created: $assignmentId");
     } on FirebaseException catch (e, stackTrace) {
         _logger.e("Repo: Firestore error creating nurse assignment", error: e, stackTrace: stackTrace);
         throw ApiException('Failed to assign patient to nurse.', statusCode: e.code.hashCode, cause: e);
     } catch (e, stackTrace) {
          _logger.e("Repo: Error creating nurse assignment", error: e, stackTrace: stackTrace);
         throw DataProcessingException('Could not create nurse assignment record.', cause: e);
     }
  }
}