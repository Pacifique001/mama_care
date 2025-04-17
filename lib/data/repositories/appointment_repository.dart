// lib/data/repositories/appointment_repository.dart

import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/nurse_assignment.dart';
import 'package:injectable/injectable.dart';

/// Abstract interface defining the contract for managing Appointment
/// and potentially related Nurse Assignment data.
/// Implementations will typically interact with backend services (like Firestore)
/// and/or local caching mechanisms.
@factoryMethod
abstract class AppointmentRepository {

  // --- Appointment Methods ---

  /// Fetches all appointments associated with a specific user ID (e.g., a patient).
  /// Returns a list of [Appointment] objects.
  /// Throws [ApiException] or [DataProcessingException] on failure.
  Future<List<Appointment>> getUserAppointments(String userId);

  /// Provides a real-time stream of appointments assigned to a specific doctor ID.
  /// Returns a Stream emitting lists of [Appointment] objects.
  /// The stream should handle errors internally or propagate them.
  Stream<List<Appointment>> getDoctorAppointments(String doctorId);

  /// Provides a real-time stream of upcoming appointments (e.g., confirmed, scheduled)
  /// assigned to a specific nurse ID.
  /// Returns a Stream emitting lists of [Appointment] objects.
  Stream<List<Appointment>> getNurseUpcomingAppointments(String nurseId);

  /// Updates the status (e.g., pending, confirmed, cancelled) of a specific appointment.
  /// Throws [ApiException] or [DataProcessingException] on failure.
  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status);

  /// Updates the scheduled time for an appointment and sets its status to rescheduled.
  /// Throws [ApiException] or [DataProcessingException] on failure.
  Future<void> rescheduleAppointment(String appointmentId, DateTime newTime);

  /// Assigns a specific nurse ID to an existing appointment record.
  /// Note: This typically only updates the appointment document itself.
  /// Throws [ApiException] or [DataProcessingException] on failure.
  Future<void> assignNurseToAppointment(String appointmentId, String nurseId);

  /// Creates a new appointment record in the data store.
  /// Takes a complete [Appointment] object (ID should be pre-generated).
  /// Returns the created [Appointment] on success.
  /// Throws [ApiException] or [DataProcessingException] on failure.
  Future<Appointment> addAppointment(Appointment appointment);


  // --- Nurse Assignment Methods ---
  // CONSIDER MOVING these to a dedicated NurseRepository for better separation.

  /// Provides a real-time stream of nurse assignment link records associated
  /// with a specific doctor ID.
  Stream<List<NurseAssignment>> getNurseAssignments(String doctorId);

  /// Creates a new record linking a nurse to a patient, initiated by a doctor.
  /// Note: This typically creates only the assignment link document. Updating
  /// related nurse/patient documents should ideally happen elsewhere (e.g., NurseRepository).
  /// Throws [ApiException] or [DataProcessingException] on failure.
  Future<void> assignPatientToNurse({
    required String nurseId,
    required String patientId,
    required String doctorId,
  });

}

// --- Removed AppointmentException ---
// It's recommended to use the more specific exceptions defined in
// lib/core/error/exceptions.dart (ApiException, DatabaseException, etc.)
// Remove the AppointmentException class definition from this file (or the original file).