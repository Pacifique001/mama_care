import 'package:injectable/injectable.dart';
import 'package:mama_care/data/local/database_helper.dart';
import '../../domain/entities/calendar_notes_model.dart';
import 'package:mama_care/data/repositories/calendar_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Import Appointment
import 'package:sqflite/sqflite.dart' as sqflite; // <--- IMPORT WITH PREFIX
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Import your custom exceptions

@Injectable(as: CalendarRepository)
class CalendarRepositoryImpl implements CalendarRepository {
   final DatabaseHelper _dbHelper;
   final FirebaseAuth _auth;
   final Logger _logger;
   // final Dio _dio; // Keep if syncing with API

   CalendarRepositoryImpl(this._dbHelper, this._auth, this._logger /*, this._dio */);

   String? get _userId => _auth.currentUser?.uid;

   @override
   Future<List<CalendarNote>> getCalendarNotesBetween(DateTime start, DateTime end) async {
      if (_userId == null) {
         _logger.w("Cannot get notes between dates: User not logged in.");
         return [];
      }
      try {
        // Pass userId
        return await _dbHelper.getCalendarNotesBetween(_userId!, start, end);
      } on sqflite.DatabaseException catch (e, stackTrace) { // <--- Catch specific sqflite exception
         _logger.e("Database error getting notes between $start and $end", error: e, stackTrace: stackTrace);
         throw DatabaseException("Failed to load calendar notes.", cause: e, stackTrace: stackTrace); // <-- Throw YOUR exception
      } catch (e, stackTrace) { // Catch other potential errors
         _logger.e("Unexpected error getting notes between $start and $end", error: e, stackTrace: stackTrace);
         throw DataProcessingException("Could not retrieve calendar notes.", cause: e, stackTrace: stackTrace);
      }
   }

  @override
  Future<CalendarNote> addNote(CalendarNote note) async {
     if (_userId == null) throw AuthException("User not logged in.");
     final noteWithUser = note.copyWith(userId: _userId);
     try {
        // Call DB method which now returns CalendarNote
       return await _dbHelper.insertCalendarNote(noteWithUser);
     } on sqflite.DatabaseException catch (e, stackTrace) { // <--- Catch specific sqflite exception
        _logger.e("Database error adding note ${note.id}", error: e, stackTrace: stackTrace);
        throw DatabaseException("Failed to save note.", cause: e, stackTrace: stackTrace); // <-- Throw YOUR exception
     } catch (e, stackTrace) {
         _logger.e("Unexpected error adding note ${note.id}", error: e, stackTrace: stackTrace);
         throw DataProcessingException("Could not save note.", cause: e, stackTrace: stackTrace);
      }
  }

  @override
  Future<int> deleteNote(String noteId) async {
    if (_userId == null) {
         _logger.w("Cannot delete note $noteId: User not logged in.");
         // Throwing an AuthException might be better than returning 0
         throw AuthException("User not logged in. Cannot delete note.");
    }
     try {
       // Pass noteId and userId
       return await _dbHelper.deleteCalendarNote(noteId, _userId!);
     } on sqflite.DatabaseException catch (e, stackTrace) { // <--- Catch specific sqflite exception
        _logger.e("Database error deleting note $noteId", error: e, stackTrace: stackTrace);
        throw DatabaseException("Failed to delete note.", cause: e, stackTrace: stackTrace); // <-- Throw YOUR exception
     } catch (e, stackTrace) {
         _logger.e("Unexpected error deleting note $noteId", error: e, stackTrace: stackTrace);
         throw DataProcessingException("Could not delete note.", cause: e, stackTrace: stackTrace);
     }
  }

  @override
    Future<List<CalendarNote>> getNotesForDate(DateTime date) async {
       // Implement similarly to getCalendarNotesBetween if needed,
       // or keep throwing UnimplementedError if not used yet.
       _logger.w("getNotesForDate is not fully implemented yet.");
       throw UnimplementedFeatureException("Fetching notes for a single date");
    }

  @override
   Future<Appointment> addAppointment(Appointment appointment) async {
       _logger.d("Repository: Adding appointment ${appointment.id}");
       if (_userId == null) throw AuthException("User not logged in.");
       final finalAppointment = appointment.userId == _userId ? appointment : appointment.copyWith(userId: _userId);

       try {
          await _dbHelper.insert(
              'appointments',
              finalAppointment.toJson(), // Use toMap or toJson
              // Use sqflite prefix for ConflictAlgorithm
              conflictAlgorithm: sqflite.ConflictAlgorithm.replace
          );
          _logger.i("Appointment ${finalAppointment.id} saved locally.");

          // Optional API Sync
          // try { ... } catch (apiError) { ... }

          return finalAppointment;

       } on sqflite.DatabaseException catch (e, stackTrace) { // <--- Catch specific sqflite exception
          _logger.e("Database error saving appointment ${finalAppointment.id}", error: e, stackTrace: stackTrace);
          // Throw YOUR custom DatabaseException, wrapping the original
          throw DatabaseException("Failed to save appointment data.", cause: e, stackTrace: stackTrace);
       } catch (e, stackTrace) { // Catch other errors during DB interaction
          _logger.e("Unexpected error saving appointment ${finalAppointment.id} in repository", error: e, stackTrace: stackTrace);
          throw DataProcessingException("Could not save appointment.", cause: e, stackTrace: stackTrace);
       }
   }

   @override
     Future<List<Appointment>> getAppointmentsForMonth(DateTime month) async {
       if (_userId == null) {
          _logger.w("Cannot get appointments for month: User not logged in.");
          return [];
       }
        final firstDay = DateTime(month.year, month.month, 1);
        final lastDay = DateTime(month.year, month.month + 1, 0);
        _logger.d("Repo: Fetching appointments for month: $month (User: $_userId)");
       try {
          final maps = await _dbHelper.query(
             'appointments',
             where: 'userId = ? AND requestedTime >= ? AND requestedTime <= ?',
             whereArgs: [_userId!, firstDay.millisecondsSinceEpoch, lastDay.millisecondsSinceEpoch],
             orderBy: 'requestedTime ASC'
          );
          // Assuming Appointment has a fromMap or use fromJson
          return maps.map((map) => Appointment.fromJson(map)).toList();
       } on sqflite.DatabaseException catch (e, stackTrace) { // <--- Catch specific sqflite exception
           _logger.e("Database error fetching appointments for month", error: e, stackTrace: stackTrace);
           throw DatabaseException("Could not load appointments.", cause: e, stackTrace: stackTrace); // <-- Throw YOUR exception
       } catch (e, stackTrace) { // Catch other errors (e.g., during mapping)
            _logger.e("Unexpected error fetching appointments for month", error: e, stackTrace: stackTrace);
            throw DataProcessingException("Could not process appointment data.", cause: e, stackTrace: stackTrace);
       }
     }

   @override
    Future<List<CalendarNote>> getNotesForMonth(DateTime month) async {
        if (_userId == null) {
           _logger.w("Cannot get notes for month: User not logged in.");
           return [];
        }
         final firstDay = DateTime(month.year, month.month, 1);
         final lastDay = DateTime(month.year, month.month + 1, 0);
         _logger.d("Fetching notes for month: $month (User: $_userId)");
         try {
            // Use the existing getCalendarNotesBetween which should internally handle exceptions
           return await _dbHelper.getCalendarNotesBetween(_userId!, firstDay, lastDay);
         } on sqflite.DatabaseException catch (e, stackTrace) { // <--- Catch specific sqflite exception
            _logger.e("Database error getting notes for month", error: e, stackTrace: stackTrace);
            throw DatabaseException("Failed to load notes for month.", cause: e, stackTrace: stackTrace); // <-- Throw YOUR exception
         } catch (e, stackTrace) {
             _logger.e("Unexpected error getting notes for month", error: e, stackTrace: stackTrace);
             throw DataProcessingException("Could not retrieve notes for month.", cause: e, stackTrace: stackTrace);
         }
    }

    // --- Implement other methods with similar error handling ---
    @override
     Future<List<Appointment>> getAppointmentsForDateRange(DateTime start, DateTime end) async {
         _logger.w("getAppointmentsForDateRange is not implemented yet.");
         throw UnimplementedFeatureException("Fetching appointments for date range");
     }
      @override
      Future<void> updateAppointment(Appointment appointment) async {
           _logger.w("updateAppointment is not implemented yet.");
          throw UnimplementedFeatureException("Updating an appointment");
      }
       @override
       Future<void> deleteAppointment(String appointmentId) async {
           _logger.w("deleteAppointment is not implemented yet.");
           throw UnimplementedFeatureException("Deleting an appointment");
      }
}