// lib/data/repositories/calendar_repository_impl.dart

import 'package:injectable/injectable.dart';
import 'package:mama_care/data/local/database_helper.dart'; // Local DB for notes
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/data/repositories/calendar_repository.dart'; // Import abstract class
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Appointment entity
import 'package:mama_care/domain/entities/appointment_status.dart'; // Status enum and helpers
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:sqflite/sqflite.dart' as sqflite; // Import sqflite with prefix
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Your custom exceptions
import 'package:uuid/uuid.dart'; // Import Uuid

@Injectable(as: CalendarRepository)
class CalendarRepositoryImpl implements CalendarRepository {
  final DatabaseHelper _dbHelper;
  final FirebaseAuth _auth;
  final Logger _logger;
  final FirebaseFirestore _firestore; // Inject Firestore
  final Uuid _uuid = const Uuid(); // For generating IDs if needed locally

  // Firestore collection reference for appointments
  late final CollectionReference _appointmentsCollection =
      _firestore.collection('appointments');

  CalendarRepositoryImpl(
    this._dbHelper,
    this._auth,
    this._logger,
    this._firestore,
  );

  /// Gets the current logged-in user's ID, or null if not logged in.
  String? get _userId => _auth.currentUser?.uid;

  // --- Note Methods (Interact with Local SQLite DB via DatabaseHelper) ---

  @override
  Future<List<CalendarNote>> getCalendarNotesBetween(
      DateTime start, DateTime end) async {
    final userId = _userId;
    if (userId == null) {
      _logger.w("Cannot get notes between dates: User not logged in.");
      return [];
    }
    _logger
        .d("Repo: Fetching notes from $start to $end for user $userId (Local DB)");
    try {
      // Delegate to DatabaseHelper, which handles SQLite specifics
      return await _dbHelper.getCalendarNotesBetween(userId, start, end);
    } on sqflite.DatabaseException catch (e, stackTrace) {
      _logger.e("SQLite error getting notes between $start and $end",
          error: e, stackTrace: stackTrace);
      throw DatabaseException("Failed to load calendar notes from local storage.",
          cause: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error getting notes between $start and $end",
          error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not retrieve calendar notes.",
          cause: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<CalendarNote> addNote(CalendarNote note) async {
    final userId = _userId;
    if (userId == null) throw AuthException("User not logged in.");

    // Ensure userId is set and generate ID if missing
    final noteToSave = note.copyWith(
      userId: userId, // Ensure correct userId
      id: note.id ?? _uuid.v4(), // Generate ID if not provided
      createdAt: note.createdAt ?? DateTime.now(), // Ensure creation time
      date: DateTime(note.date.year, note.date.month, note.date.day), // Normalize date
    );

    _logger.d("Repo: Adding note ${noteToSave.id} for user $userId (Local DB)");
    try {
      // Delegate to DatabaseHelper
      return await _dbHelper.insertCalendarNote(noteToSave);
    } on sqflite.DatabaseException catch (e, stackTrace) {
      _logger.e("SQLite error adding note ${noteToSave.id}", error: e, stackTrace: stackTrace);
      throw DatabaseException("Failed to save note locally.",
          cause: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error adding note ${noteToSave.id}", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not save note.",
          cause: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final userId = _userId;
    if (userId == null) {
      throw AuthException("User not logged in. Cannot delete note.");
    }
    _logger.d("Repo: Deleting note $noteId for user $userId (Local DB)");
    try {
      // Delegate to DatabaseHelper
      final count = await _dbHelper.deleteCalendarNote(noteId, userId);
      if (count == 0) {
        _logger.w("Attempted to delete non-existent or unauthorized note: $noteId");
        // Optional: throw NotFoundException("Note not found or permission denied.");
      } else {
         _logger.i("Successfully deleted note $noteId from local DB.");
      }
    } on sqflite.DatabaseException catch (e, stackTrace) {
      _logger.e("SQLite error deleting note $noteId", error: e, stackTrace: stackTrace);
      throw DatabaseException("Failed to delete note from local storage.",
          cause: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error deleting note $noteId", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not delete note.",
          cause: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<List<CalendarNote>> getNotesForDate(DateTime date) async {
    // Normalizes date and calls getCalendarNotesBetween
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return getCalendarNotesBetween(startOfDay, endOfDay); // Reuse existing logic
  }

  @override
  Future<List<CalendarNote>> getNotesForMonth(DateTime month) async {
    // Calculates month range and calls getCalendarNotesBetween
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    return getCalendarNotesBetween(firstDay, lastDay); // Reuse existing logic
  }

  // --- Appointment Methods (Interact with Firestore) ---

  @override
  Future<List<Appointment>> getAppointmentsForDate(DateTime date) async {
    final userId = _userId;
    if (userId == null) {
      _logger.w("Cannot get appointments for date: User not logged in.");
      return [];
    }
    final startOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final endOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day, 23, 59, 59, 999));
    _logger.d("Repo: Fetching appointments for date: ${date.toIso8601String()} (User: $userId) from Firestore");

    try {
      // Perform parallel queries
      final patientQuery = _appointmentsCollection
          .where('patientId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThanOrEqualTo: endOfDay)
          .get();

      final doctorQuery = _appointmentsCollection
          .where('doctorId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThanOrEqualTo: endOfDay)
          .get();

       // Add Nurse query if nurses can view appointments this way
       final nurseQuery = _appointmentsCollection
            .where('nurseId', isEqualTo: userId)
            .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
            .where('dateTime', isLessThanOrEqualTo: endOfDay)
            .get();

      // Await all queries
      final results = await Future.wait([patientQuery, doctorQuery, nurseQuery]);

      final Set<String> uniqueIds = {};
      final List<Appointment> appointments = [];

      // Merge results, ensuring uniqueness
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (uniqueIds.add(doc.id)) {
            try {
              // Use the fromFirestore factory defined in Appointment entity
              appointments.add(Appointment.fromFirestore(doc));
            } catch (e, s) {
              _logger.e("Error parsing appointment ${doc.id} for date", error: e, stackTrace: s);
            }
          }
        }
      }

      // Sort by time
      appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      _logger.i("Fetched ${appointments.length} appointments for date ${date.toIso8601String()}");
      return appointments;

    } on FirebaseException catch (e, stackTrace) {
      _logger.e("Firestore error fetching appointments for date", error: e, stackTrace: stackTrace);
      throw ApiException("Could not load appointments for date.", cause: e);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error fetching appointments for date", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not process appointment data for date.", cause: e);
    }
  }

  @override
  Future<List<Appointment>> getAppointmentsForMonth(DateTime month) async {
    final firstDay = DateTime(month.year, month.month, 1);
    // Correctly calculate the last moment of the last day of the month
    final lastDay = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));
    return getAppointmentsForDateRange(firstDay, lastDay); // Delegate
  }

  @override
  Future<List<Appointment>> getAppointmentsForDateRange(DateTime start, DateTime end) async {
    final userId = _userId;
    if (userId == null) {
      _logger.w("Cannot get appointments for date range: User not logged in.");
      return [];
    }
    _logger.d("Repo: Fetching appointments from $start to $end (User: $userId) from Firestore");
    try {
      final startTs = Timestamp.fromDate(start);
      // Ensure end captures the whole day
      final endOfDayEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
      final endTs = Timestamp.fromDate(endOfDayEnd);

      // Combine queries
      final patientQuery = _appointmentsCollection
          .where('patientId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: startTs)
          .where('dateTime', isLessThanOrEqualTo: endTs)
          .get();

      final doctorQuery = _appointmentsCollection
          .where('doctorId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: startTs)
          .where('dateTime', isLessThanOrEqualTo: endTs)
          .get();

      final nurseQuery = _appointmentsCollection
          .where('nurseId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: startTs)
          .where('dateTime', isLessThanOrEqualTo: endTs)
          .get();

      final results = await Future.wait([patientQuery, doctorQuery, nurseQuery]);

      final Set<String> uniqueIds = {};
      final List<Appointment> appointments = [];
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (uniqueIds.add(doc.id)) {
            try {
              appointments.add(Appointment.fromFirestore(doc));
            } catch (e, s) {
              _logger.e("Error parsing appointment ${doc.id} for date range", error: e, stackTrace: s);
            }
          }
        }
      }

      appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      _logger.i("Fetched ${appointments.length} appointments for date range $start - $end");
      return appointments;

    } on FirebaseException catch (e, stackTrace) {
      _logger.e("Firestore error fetching appointments for date range", error: e, stackTrace: stackTrace);
      throw ApiException("Could not load appointments.", cause: e);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error fetching appointments for date range", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not process appointment data.", cause: e);
    }
  }

  @override
  Future<Appointment> addAppointment(Appointment appointment) async {
    _logger.d("Repo: Adding appointment (Calendar Repo)");
    final userId = _userId;
    if (userId == null) throw AuthException("User not logged in.");

    // Ensure patientId is set, default to current user if logic requires
    final finalAppointment = (appointment.patientId == null || appointment.patientId!.isEmpty)
        ? appointment.copyWith(patientId: userId)
        : appointment;

    // ID should be generated by Firestore, ensure local ID is null or ignored
    final appointmentMap = finalAppointment.toMapForCreation(); // Uses Timestamps, server times

    try {
      final docRef = await _appointmentsCollection.add(appointmentMap);
      _logger.i("Appointment ${docRef.id} created in Firestore.");

      // Return appointment with the generated ID and potentially fetched server timestamps
      // Fetching back is safer to get accurate timestamps
       final createdDoc = await docRef.get();
       return Appointment.fromFirestore(createdDoc);
       // Or return local copy with ID if fetching back is too slow/complex here
       // return finalAppointment.copyWith(id: docRef.id);

    } on FirebaseException catch (e, stackTrace) {
      _logger.e("Firestore error saving appointment", error: e, stackTrace: stackTrace);
      throw ApiException("Failed to save appointment.", cause: e);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error saving appointment", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not save appointment.", cause: e);
    }
  }

  @override
  Future<void> updateAppointment(Appointment appointment) async {
    _logger.d("Repo: Updating appointment ${appointment.id} (Calendar Repo)");
    final userId = _userId;
    if (userId == null) throw AuthException("User not logged in.");
    if (appointment.id == null || appointment.id!.isEmpty) {
      throw ArgumentError("Appointment ID required for update.");
    }

    // Optional: Permission Check (can user update this specific appointment?)
    // Fetch original doc first if needed for permission check based on roles
    // final doc = await _appointmentsCollection.doc(appointment.id!).get();
    // if (!doc.exists) throw DataNotFoundException("Appointment ${appointment.id} not found.");
    // if (!_canUserUpdate(userId, doc.data() as Map<String, dynamic>)) { // Implement _canUserUpdate logic
    //   throw PermissionException("You don't have permission to update this appointment.");
    // }

    try {
      // Use a map suitable for Firestore updates (includes server timestamp for updatedAt)
      final updateMap = appointment.toMapForUpdate();
      await _appointmentsCollection.doc(appointment.id!).update(updateMap);
      _logger.i("Successfully updated appointment ${appointment.id}");
    } on FirebaseException catch (e, stackTrace) {
      _logger.e("Firestore error updating appointment ${appointment.id}", error: e, stackTrace: stackTrace);
      if (e.code == 'not-found') {
        throw DataNotFoundException("Appointment ${appointment.id} not found for update.");
      }
      throw ApiException("Failed to update appointment.", cause: e);
    } catch (e, stackTrace) {
      _logger.e("Unexpected error updating appointment ${appointment.id}", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not update appointment.", cause: e);
    }
  }

  @override
  Future<void> deleteAppointment(String appointmentId) async {
    _logger.d("Repo: Deleting appointment $appointmentId (Calendar Repo)");
    final userId = _userId;
    if (userId == null) throw AuthException("User not logged in.");
    if (appointmentId.isEmpty) throw ArgumentError("Appointment ID required for deletion.");

    // Optional: Permission Check
    // final doc = await _appointmentsCollection.doc(appointmentId).get();
    // if (!doc.exists) { _logger.w("Appointment $appointmentId not found for deletion."); return; } // Don't throw if delete is idempotent
    // if (!_canUserDelete(userId, doc.data() as Map<String, dynamic>)) { // Implement _canUserDelete logic
    //    throw PermissionException("You don't have permission to delete this appointment.");
    // }

    try {
      await _appointmentsCollection.doc(appointmentId).delete();
      _logger.i("Successfully deleted appointment $appointmentId");
    } on FirebaseException catch (e, stackTrace) {
      _logger.e("Firestore error deleting appointment $appointmentId", error: e, stackTrace: stackTrace);
      // Don't throw for not-found on delete usually, treat as success
      if (e.code != 'not-found') {
         throw ApiException("Failed to delete appointment.", cause: e);
      } else {
         _logger.w("Attempted to delete appointment $appointmentId which was already deleted or never existed.");
      }
    } catch (e, stackTrace) {
      _logger.e("Unexpected error deleting appointment $appointmentId", error: e, stackTrace: stackTrace);
      throw DataProcessingException("Could not delete appointment.", cause: e);
    }
  }
}

