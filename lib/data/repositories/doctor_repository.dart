// lib/data/repositories/doctor_repository.dart

import 'package:mama_care/domain/entities/doctor.dart'; // Import the Doctor entity
import 'package:injectable/injectable.dart';

/// Abstract interface for accessing Doctor data.
///
@factoryMethod
abstract class DoctorRepository {
  /// Fetches a list of doctors available for selection (e.g., for appointments).
  ///
  /// May include filtering logic based on criteria like specialty, location,
  /// or doctor availability if needed in the future, passed via optional parameters.
  Future<List<Doctor>> getAvailableDoctors({String? specialtyFilter}); // Added optional filter example

  /// Fetches a specific doctor's profile by their ID.
  Future<Doctor?> getDoctorById(String doctorId);

  // Add other methods related to doctors if needed, e.g.:
  // Future<List<Doctor>> searchDoctors(String query);
}