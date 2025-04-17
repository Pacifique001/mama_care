// lib/domain/usecases/nurse_dashboard_usecase.dart

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/data/repositories/nurse_repository.dart'; // Import Nurse Repo
import 'package:mama_care/data/repositories/appointment_repository.dart'; // Import Appointment Repo
import 'package:mama_care/domain/entities/nurse.dart';
import 'package:mama_care/domain/entities/patient_summary.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Import Appointment

@injectable
class NurseDashboardUseCase {
  final NurseRepository _nurseRepository;
  final AppointmentRepository _appointmentRepository; // To get nurse's appointments
  final Logger _logger;

  NurseDashboardUseCase(this._nurseRepository, this._appointmentRepository, this._logger);

  /// Gets the profile for the specified nurse.
  Future<Nurse?> getNurseProfile(String nurseId) async {
    _logger.d("UseCase: Getting nurse profile $nurseId");
    if (nurseId.isEmpty) throw ArgumentError("Nurse ID cannot be empty.");
    try {
      return await _nurseRepository.getCurrentNurseProfile(nurseId); // Use specific repo method
    } catch (e) { rethrow; }
  }

  /// Gets patients assigned to the nurse.
  Future<List<PatientSummary>> getAssignedPatients(String nurseId) async {
    _logger.d("UseCase: Getting assigned patients for nurse $nurseId");
     if (nurseId.isEmpty) throw ArgumentError("Nurse ID cannot be empty.");
    try {
      return await _nurseRepository.getAssignedPatients(nurseId);
    } catch (e) { rethrow; }
  }

  /// Gets upcoming appointments specifically for the nurse.
  Future<Stream<List<Appointment>>> getUpcomingAppointments(String nurseId) async {
     _logger.d("UseCase: Getting upcoming appointments for nurse $nurseId");
     if (nurseId.isEmpty) throw ArgumentError("Nurse ID cannot be empty.");
     try {
        // Assuming AppointmentRepository has a method like this
        // Alternatively, filter appointments in the ViewModel if repo returns all user's appts
       return _appointmentRepository.getNurseUpcomingAppointments(nurseId);
     } catch (e) { rethrow; }
  }

  // Add other use cases relevant to the nurse dashboard if needed
}

// --- TODO: Ensure AppointmentRepository has getNurseUpcomingAppointments ---
// Example signature in lib/data/repositories/appointment_repository.dart
// abstract class AppointmentRepository {
//   ...
//   Future<List<Appointment>> getNurseUpcomingAppointments(String nurseId);
//   ...
// }
// Implement it in AppointmentRepositoryImpl