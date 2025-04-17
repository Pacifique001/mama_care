// lib/domain/usecases/doctor_usecase.dart

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/data/repositories/doctor_repository.dart'; // Import Repository interface
import 'package:mama_care/domain/entities/doctor.dart';          // Import Entity

@injectable // Make the UseCase injectable
class DoctorUseCase {
  final DoctorRepository _repository;
  final Logger _logger;

  DoctorUseCase(this._repository, this._logger);

  /// Gets a list of available doctors, potentially applying filters.
  Future<List<Doctor>> getAvailableDoctors({String? specialtyFilter}) async {
    _logger.d("UseCase: Getting available doctors...");
    try {
      // Can add business logic here before or after repository call if needed
      final doctors = await _repository.getAvailableDoctors(specialtyFilter: specialtyFilter);
      _logger.i("UseCase: Retrieved ${doctors.length} available doctors.");
      // Example Business Logic: Sort by name (although repo already does it)
      // doctors.sort((a, b) => a.name.compareTo(b.name));
      return doctors;
    } catch (e) {
       _logger.e("UseCase: Failed to get available doctors.", error: e);
       // Re-throw the exception to be handled by the ViewModel
       rethrow;
    }
  }

  /// Gets a specific doctor by ID.
  Future<Doctor?> getDoctorById(String doctorId) async {
     _logger.d("UseCase: Getting doctor by ID $doctorId...");
     try {
        final doctor = await _repository.getDoctorById(doctorId);
        if (doctor == null) {
           _logger.w("UseCase: Doctor $doctorId not found.");
        } else {
            _logger.i("UseCase: Retrieved doctor ${doctor.name}.");
        }
        return doctor;
     } catch (e) {
        _logger.e("UseCase: Failed to get doctor $doctorId.", error: e);
        rethrow;
     }
  }

  // Add other doctor-related use cases here if needed...
}