// lib/data/repositories/nurse_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart';
import 'package:mama_care/data/repositories/nurse_repository.dart';
import 'package:mama_care/domain/entities/nurse.dart';
import 'package:mama_care/domain/entities/nurse_assignment.dart';
import 'package:mama_care/domain/entities/patient_summary.dart'; // Import PatientSummary
import 'package:uuid/uuid.dart';

@Injectable(as: NurseRepository)
class NurseRepositoryImpl implements NurseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;
  final Uuid _uuid;

  late final CollectionReference _nursesCollection = _firestore.collection('nurses');
  late final CollectionReference _assignmentsCollection = _firestore.collection('nurse_assignments');
  late final CollectionReference _patientsCollection = _firestore.collection('patients'); // Or 'users'

  NurseRepositoryImpl(this._firestore, this._auth, this._logger, this._uuid);

  @override
  Future<List<Nurse>> getAvailableNurses(String? contextId) async {
    // ... (Implementation from previous step - remains the same) ...
     _logger.d("Repository: Fetching available nurses (context: $contextId)...");
    try {
      final querySnapshot = await _nursesCollection
           .where('currentPatientLoad', isLessThan: 5)
          .orderBy('name')
          .get();
      final nurses = querySnapshot.docs.map((doc) => Nurse.fromFirestore(doc)).toList();
      _logger.i("Repository: Fetched ${nurses.length} available nurses.");
      return nurses;
    } catch (e, stackTrace) {
      _logger.e("Repository: Error fetching available nurses", error: e, stackTrace: stackTrace);
      throw ApiException("Could not load available nurses.", cause: e);
    }
  }

  @override
  Future<void> assignNurseToContext({
    required String contextId, // Assuming patientId
    required String nurseId,
    required String doctorId,
  }) async {
    // ... (Implementation from previous step - remains the same) ...
     _logger.i("Repository: Assigning nurse $nurseId to patient $contextId by doctor $doctorId");
    final patientId = contextId;
    final WriteBatch batch = _firestore.batch();
    try {
      // Optional: Create Assignment Record
      final assignmentId = _uuid.v4();
      final assignmentRef = _assignmentsCollection.doc(assignmentId);
      final newAssignment = NurseAssignment( id: assignmentId, nurseId: nurseId, patientId: patientId, doctorId: doctorId, assignedAt: DateTime.now() );
       batch.set(assignmentRef, newAssignment.toFirestoreMap());
       _logger.d("Batch: Added NurseAssignment record $assignmentId");

      // Update Patient
      final patientRef = _patientsCollection.doc(patientId);
      batch.update(patientRef, {'assignedNurseId': nurseId});
       _logger.d("Batch: Updated patient $patientId with nurse $nurseId");

      // Update Nurse Load
      final nurseRef = _nursesCollection.doc(nurseId);
      batch.update(nurseRef, {'currentPatientLoad': FieldValue.increment(1)});
       _logger.d("Batch: Incremented patient load for nurse $nurseId");

      await batch.commit();
      _logger.i("Repository: Successfully assigned nurse $nurseId to patient $patientId.");
    } catch (e, stackTrace) {
      _logger.e("Repository: Error assigning nurse $nurseId to patient $patientId", error: e, stackTrace: stackTrace);
      throw ApiException("Failed to complete nurse assignment.", cause: e);
    }
  }

   @override
   Future<Nurse?> getNurseById(String nurseId) async {
     // ... (Implementation from previous step - remains the same) ...
      _logger.d("Repository: Fetching nurse profile for ID: $nurseId");
      if (nurseId.isEmpty) return null;
      try {
        final doc = await _nursesCollection.doc(nurseId).get();
        if (doc.exists) { return Nurse.fromFirestore(doc); }
        else { _logger.w("Repository: Nurse with ID $nurseId not found."); return null; }
      } catch (e, stackTrace) {
         _logger.e("Repository: Error fetching nurse $nurseId", error: e, stackTrace: stackTrace);
        throw ApiException("Could not load nurse profile.", cause: e);
      }
   }

  // --- NEW IMPLEMENTATIONS ---

  @override
  Future<List<PatientSummary>> getAssignedPatients(String nurseId) async {
    _logger.d("Repository: Fetching assigned patients for nurse $nurseId");
    if (nurseId.isEmpty) return [];
    try {
      // Option A: Query patients collection directly if nurseId is stored there
      final patientSnapshot = await _patientsCollection
          .where('assignedNurseId', isEqualTo: nurseId)
          // Add .where('isActive', isEqualTo: true) if applicable
          .orderBy('name') // Order patients by name
          .get();

      final patients = patientSnapshot.docs
          .map((doc) => PatientSummary.fromFirestore(doc)) // Use PatientSummary factory
          .toList();
      _logger.i("Repository: Found ${patients.length} patients assigned to nurse $nurseId via patient collection query.");
      return patients;

      // Option B: If using an assignments collection or patientIds array on nurse doc
      // 1. Get nurse doc / assignments collection
      // 2. Extract patient IDs
      // 3. Fetch patient summaries for those IDs (potentially requires PatientRepository)

    } on FirebaseException catch (e, stackTrace) {
        _logger.e("Repository: Firestore error fetching assigned patients for nurse $nurseId", error: e, stackTrace: stackTrace);
        throw ApiException("Error loading assigned patients.", statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
      _logger.e("Repository: Unexpected error fetching assigned patients for nurse $nurseId", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not process assigned patient data.", cause: e);
    }
  }

  @override
  Future<void> unassignPatient({required String nurseId, required String patientId}) async {
    _logger.i("Repository: Unassigning patient $patientId from nurse $nurseId");
    if (nurseId.isEmpty || patientId.isEmpty) {
       throw ArgumentError("Nurse ID and Patient ID cannot be empty for unassignment.");
    }

    final WriteBatch batch = _firestore.batch();
    try {
      // 1. Update the Patient document: Remove assignedNurseId or set to null
      final patientRef = _patientsCollection.doc(patientId);
      batch.update(patientRef, {'assignedNurseId': FieldValue.delete()}); // Or set to null
      _logger.d("Batch: Removed assignedNurseId from patient $patientId");

      // 2. Update the Nurse document: Decrement patient count
      final nurseRef = _nursesCollection.doc(nurseId);
      batch.update(nurseRef, {'currentPatientLoad': FieldValue.increment(-1)});
      // Option B: Remove patientId from patientIds array if using that model
      // batch.update(nurseRef, {'patientIds': FieldValue.arrayRemove([patientId])});
       _logger.d("Batch: Decremented patient load for nurse $nurseId");

      // 3. Delete the NurseAssignment record if you have one
      // Query the assignments collection for the specific assignment doc ID first
      // final assignmentQuery = await _assignmentsCollection
      //    .where('nurseId', isEqualTo: nurseId)
      //    .where('patientId', isEqualTo: patientId)
      //    .limit(1).get();
      // if (assignmentQuery.docs.isNotEmpty) {
      //    batch.delete(assignmentQuery.docs.first.reference);
      //     _logger.d("Batch: Deleting NurseAssignment record ${assignmentQuery.docs.first.id}");
      // } else {
      //    _logger.w("Could not find specific assignment record to delete for nurse $nurseId / patient $patientId");
      // }

      // Commit batch
      await batch.commit();
      _logger.i("Repository: Successfully unassigned patient $patientId from nurse $nurseId.");

    } catch (e, stackTrace) {
      _logger.e("Repository: Error unassigning patient $patientId from nurse $nurseId", error: e, stackTrace: stackTrace);
      // Handle specific errors (e.g., nurse/patient not found during update?)
      throw ApiException("Failed to complete patient unassignment.", cause: e);
    }
  }
  @override
  Future<Nurse?> getCurrentNurseProfile(String nurseId) async {
    _logger.d("Repository: Fetching current nurse profile for ID: $nurseId");
    // This might be identical to getNurseById, or could fetch extra private info
    // For simplicity, reuse getNurseById logic
    if (nurseId.isEmpty) { _logger.w("Empty nurseId passed."); return null; }
    try {
      final doc = await _nursesCollection.doc(nurseId).get();
      if (doc.exists) {
        return Nurse.fromFirestore(doc);
      } else {
        _logger.w("Repository: Current Nurse profile with ID $nurseId not found.");
        // Maybe try creating a basic profile from Auth details if Firestore doc missing?
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.uid == nurseId) {
            _logger.w("Creating basic nurse profile from Auth for $nurseId");
             // You'd need a way to determine specialty and patient load here, likely defaults
            return Nurse(id: nurseId, name: currentUser.displayName ?? 'Nurse', currentPatientLoad: 0);
        }
        return null;
      }
    } on FirebaseException catch (e, stackTrace) {
       _logger.e("Repository: Firestore error fetching current nurse $nurseId", error: e, stackTrace: stackTrace);
      throw ApiException("Error fetching your profile.", statusCode: e.code.hashCode, cause: e);
    } catch (e, stackTrace) {
       _logger.e("Repository: Unexpected error fetching current nurse $nurseId", error: e, stackTrace: stackTrace);
       throw DataProcessingException("Could not process your profile data.", cause: e);
    }
  }

}