// lib/data/repositories/doctor_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Import custom exceptions
import 'package:mama_care/data/repositories/doctor_repository.dart'; // Import the interface
import 'package:mama_care/domain/entities/doctor.dart'; // Import the entity

@Injectable(as: DoctorRepository) // Bind implementation to the interface
class DoctorRepositoryImpl implements DoctorRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  // Assuming 'doctors' is the name of your Firestore collection
  late final CollectionReference _doctorsCollection = _firestore.collection('doctors');

  DoctorRepositoryImpl(this._firestore, this._logger) {
    _logger.i("DoctorRepositoryImpl initialized.");
  }

  @override
  Future<List<Doctor>> getAvailableDoctors({String? specialtyFilter}) async {
    _logger.d("Repository: Fetching available doctors${specialtyFilter != null ? ' with specialty: $specialtyFilter' : ''}...");
    try {
      Query query = _doctorsCollection;

      // Add filtering if needed
      if (specialtyFilter != null && specialtyFilter.isNotEmpty) {
          query = query.where('specialty', isEqualTo: specialtyFilter);
           _logger.d("Applying specialty filter: $specialtyFilter");
      }

      // Add other filters like 'isAcceptingNewPatients', 'isActive' if they exist in Firestore
      // query = query.where('isActive', isEqualTo: true);

      // Order results (e.g., by name)
      query = query.orderBy('name');

      final querySnapshot = await query.get();

      final doctors = querySnapshot.docs
          .map((doc) => Doctor.fromFirestore(doc)) // Use factory from entity
          .toList();

      _logger.i("Repository: Fetched ${doctors.length} available doctors.");
      return doctors;

    } on FirebaseException catch (e, stackTrace) {
       _logger.e("Repository: Firestore error fetching doctors", error: e, stackTrace: stackTrace);
       throw ApiException("Error fetching doctors from database.", statusCode: e.code.hashCode, cause: e); // Use ApiException for Firestore errors
    } catch (e, stackTrace) {
      _logger.e("Repository: Unexpected error fetching doctors", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not process doctor data.", cause: e);
    }
  }

  @override
  Future<Doctor?> getDoctorById(String doctorId) async {
    _logger.d("Repository: Fetching doctor by ID: $doctorId");
    if (doctorId.isEmpty) return null;

    try {
      final docSnapshot = await _doctorsCollection.doc(doctorId).get();

      if (docSnapshot.exists) {
         _logger.i("Repository: Found doctor $doctorId.");
        return Doctor.fromFirestore(docSnapshot);
      } else {
         _logger.w("Repository: Doctor with ID $doctorId not found.");
        return null; // Return null if document doesn't exist
      }
    } on FirebaseException catch (e, stackTrace) {
        _logger.e("Repository: Firestore error fetching doctor $doctorId", error: e, stackTrace: stackTrace);
        throw ApiException("Error fetching doctor details.", statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
      _logger.e("Repository: Unexpected error fetching doctor $doctorId", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not process doctor details.", cause: e);
    }
  }
}