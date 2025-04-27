// lib/data/repositories/appointment_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Your custom exceptions
import 'package:mama_care/data/repositories/appointment_repository.dart'; // The abstract class
import 'package:mama_care/domain/entities/appointment.dart'; // Your Appointment entity
import 'package:mama_care/domain/entities/appointment_status.dart'; // Your Status enum and helpers

@Injectable(as: AppointmentRepository) // Implement the interface
class AppointmentRepositoryImpl implements AppointmentRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  // Reference to the Firestore collection where appointments are stored
  late final CollectionReference _appointmentsCollection = _firestore
      .collection('appointments');

  AppointmentRepositoryImpl(this._firestore, this._logger) {
    _logger.i("AppointmentRepositoryImpl initialized.");
  }

  /// Creates a new appointment document in Firestore.
  @override
  Future<String> createAppointment(Appointment appointment) async {
    _logger.d(
      "Repository: Creating appointment for patient ${appointment.patientId} with doctor ${appointment.doctorId}",
    );
    try {
      // Convert the Appointment entity to a Map suitable for Firestore creation
      // This map should include server timestamps for createdAt/updatedAt
      final dataMap = appointment.toMapForCreation();
      final docRef = await _appointmentsCollection.add(dataMap);
      _logger.i("Repository: Created appointment with ID ${docRef.id}");
      return docRef.id; // Return the auto-generated Firestore document ID
    } on FirebaseException catch (e, stackTrace) {
      _logger.e(
        "Repository: Firestore error creating appointment",
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap Firebase error in a custom domain/data layer exception
      throw ApiException("Error creating appointment in Firestore.", cause: e);
    } catch (e, stackTrace) {
      _logger.e(
        "Repository: Unexpected error creating appointment",
        error: e,
        stackTrace: stackTrace,
      );
      // Wrap other errors
      throw DataProcessingException(
        "Could not create appointment data.",
        cause: e,
      );
    }
  }

  /// Fetches appointments where the given ID matches the patientId.
  /// Optionally filters by status.
  @override
  Future<List<Appointment>> getPatientAppointments(
    String patientId, {
    AppointmentStatus? status,
  }) async {
    _logger.d(
      "Repository: Fetching appointments for patient $patientId${status != null ? ' with status: ${status.name}' : ''}",
    );
    if (patientId.isEmpty) {
      _logger.w("getPatientAppointments called with empty patientId.");
      return [];
    }
    try {
      // Start building the query
      Query query = _appointmentsCollection.where(
        'patientId',
        isEqualTo: patientId,
      );

      // Apply status filter if provided
      if (status != null) {
        // Convert the enum status to its string representation for the Firestore query
        query = query.where(
          'status',
          isEqualTo: appointmentStatusToString(status),
        );
      }

      // Order results (e.g., most recent appointment first)
      query = query.orderBy('dateTime', descending: true);

      final querySnapshot = await query.get();

      // Map Firestore documents to Appointment entities
      final appointments =
          querySnapshot.docs
              .map((doc) {
                try {
                  return Appointment.fromFirestore(doc);
                } catch (e, s) {
                  // Log error for specific document but don't crash the whole fetch
                  _logger.e(
                    "Error parsing patient appointment ${doc.id}",
                    error: e,
                    stackTrace: s,
                  );
                  return null; // Indicate failure to parse this doc
                }
              })
              .whereType<Appointment>()
              .toList(); // Filter out any nulls from parsing errors

      _logger.i(
        "Repository: Fetched ${appointments.length} appointments for patient $patientId",
      );
      return appointments;
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error fetching patient appointments for $patientId",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error fetching patient appointments.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error fetching patient appointments for $patientId",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException(
        "Could not process patient appointment data.",
        cause: e,
      );
    }
  }

  /// Fetches appointments where the given ID matches the doctorId.
  /// Optionally filters by status.
  @override
  Future<List<Appointment>> getDoctorAppointments(
    String doctorId, {
    AppointmentStatus? status,
  }) async {
    _logger.d(
      "Repository: Fetching appointments for doctor $doctorId${status != null ? ' with status: ${status.name}' : ''}",
    );
    if (doctorId.isEmpty) {
      _logger.w("getDoctorAppointments called with empty doctorId.");
      return [];
    }
    try {
      Query query = _appointmentsCollection.where(
        'doctorId',
        isEqualTo: doctorId,
      );
      if (status != null) {
        query = query.where(
          'status',
          isEqualTo: appointmentStatusToString(status),
        ); // Convert enum to string
      }
      // Order (e.g., upcoming appointments first)
      query = query.orderBy('dateTime', descending: false);
      final querySnapshot = await query.get();
      final appointments =
          querySnapshot.docs
              .map((doc) {
                try {
                  return Appointment.fromFirestore(doc);
                } catch (e, s) {
                  _logger.e(
                    "Error parsing doctor appt ${doc.id}",
                    error: e,
                    stackTrace: s,
                  );
                  return null;
                }
              })
              .whereType<Appointment>()
              .toList();
      _logger.i(
        "Repository: Fetched ${appointments.length} appointments for doctor $doctorId",
      );
      return appointments;
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error fetching doctor appointments for $doctorId",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error fetching doctor appointments.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error fetching doctor appointments for $doctorId",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException(
        "Could not process doctor appointment data.",
        cause: e,
      );
    }
  }

  /// Fetches a single appointment by its Firestore document ID.
  @override
  Future<Appointment?> getAppointmentById(String appointmentId) async {
    _logger.d("Repository: Fetching appointment by ID: $appointmentId");
    if (appointmentId.isEmpty) {
      _logger.w("getAppointmentById called with empty ID.");
      return null;
    }
    try {
      final docSnapshot =
          await _appointmentsCollection.doc(appointmentId).get();
      if (docSnapshot.exists) {
        _logger.i("Repository: Found appointment $appointmentId");
        return Appointment.fromFirestore(docSnapshot);
      } else {
        _logger.w("Repository: Appointment with ID $appointmentId not found");
        return null;
      }
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error fetching appointment $appointmentId",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error fetching appointment details.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error fetching appointment $appointmentId",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException(
        "Could not process appointment details.",
        cause: e,
      );
    }
  }

  /// Updates only the status and updatedAt fields of an appointment.
  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    _logger.d(
      "Repository: Updating status for appointment $appointmentId to ${status.name}",
    );
    if (appointmentId.isEmpty) {
      throw ArgumentError("Appointment ID cannot be empty for status update.");
    }
    try {
      // Prepare data for update: convert enum status to string and set server timestamp
      final updateData = {
        'status': appointmentStatusToString(status),
        'updatedAt':
            FieldValue.serverTimestamp(), // Use server timestamp for consistency
      };
      await _appointmentsCollection.doc(appointmentId).update(updateData);
      _logger.i("Repository: Status updated successfully for $appointmentId.");
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error updating status for $appointmentId",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error updating appointment status.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error updating status for $appointmentId",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException(
        "Could not update appointment status.",
        cause: e,
      );
    }
  }

  /// Updates the entire appointment document (or specific fields).
  /// Note: Be cautious using this if you only need to update specific fields like status.
  @override
  Future<void> updateAppointment(Appointment appointment) async {
    _logger.d("Repository: Updating full appointment ${appointment.id}");
    if (appointment.id == null || appointment.id!.isEmpty) {
      throw ArgumentError("Appointment ID is required for updates.");
    }
    try {
      // Prepare data, ensuring updatedAt is set
      final dataToUpdate =
          appointment.toMapForCreation(); // Re-use creation map temporarily
      dataToUpdate['updatedAt'] =
          FieldValue.serverTimestamp(); // Override with server timestamp

      // Remove createdAt if it exists in the map to prevent overwriting
      dataToUpdate.remove('createdAt');

      await _appointmentsCollection.doc(appointment.id).update(dataToUpdate);
      _logger.i("Repository: Updated appointment ${appointment.id}");
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error updating appointment ${appointment.id}",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error updating appointment.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error updating appointment ${appointment.id}",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException("Could not update appointment.", cause: e);
    }
  }

  /// Deletes an appointment document from Firestore.
  @override
  Future<void> deleteAppointment(String appointmentId) async {
    _logger.d("Repository: Deleting appointment $appointmentId");
    if (appointmentId.isEmpty) {
      throw ArgumentError("Appointment ID cannot be empty for deletion.");
    }
    try {
      await _appointmentsCollection.doc(appointmentId).delete();
      _logger.i("Repository: Deleted appointment $appointmentId");
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error deleting appointment $appointmentId",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error deleting appointment.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error deleting appointment $appointmentId",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException("Could not delete appointment.", cause: e);
    }
  }

  /// Fetches all appointments related to a user (as patient OR doctor).
  @override
  Future<List<Appointment>> getUserAppointments(String userId) async {
    _logger.d("Repository: Fetching appointments related to user ID: $userId");
    if (userId.isEmpty) {
      _logger.w("getUserAppointments called with empty userId.");
      return [];
    }

    try {
      // Firestore doesn't support OR queries on different fields efficiently.
      // Fetching separately and merging is standard practice.
      final patientQuery = _appointmentsCollection.where(
        'patientId',
        isEqualTo: userId,
      );
      final doctorQuery = _appointmentsCollection.where(
        'doctorId',
        isEqualTo: userId,
      );
      // Add other roles if needed (e.g., nurseId)
      // final nurseQuery = _appointmentsCollection.where('assignedNurseId', isEqualTo: userId);

      final List<QuerySnapshot> snapshots = await Future.wait([
        patientQuery.get(),
        doctorQuery.get(),
        // nurseQuery.get(),
      ]);

      final Set<String> uniqueIds = {}; // To prevent duplicates
      final List<Appointment> allAppointments = [];

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          if (uniqueIds.add(doc.id)) {
            // Only add if not already added
            try {
              allAppointments.add(Appointment.fromFirestore(doc));
            } catch (e, s) {
              _logger.e(
                "Error parsing appointment ${doc.id} in getUserAppointments",
                error: e,
                stackTrace: s,
              );
            }
          }
        }
      }

      // Sort the combined list by appointment time (most recent first)
      allAppointments.sort(
        (a, b) => b.dateTime.compareTo(a.dateTime),
      ); // Compare Timestamps directly

      _logger.i(
        "Repository: Fetched ${allAppointments.length} total appointments related to user $userId",
      );
      return allAppointments;
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Repository: Firestore error fetching user appointments for $userId",
        error: e,
        stackTrace: s,
      );
      throw ApiException("Error fetching user appointments.", cause: e);
    } catch (e, s) {
      _logger.e(
        "Repository: Unexpected error fetching user appointments for $userId",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException(
        "Could not process user appointment data.",
        cause: e,
      );
    }
  }
}
