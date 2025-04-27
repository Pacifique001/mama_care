// lib/domain/repositories/calendar_repository.dart

import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Import Appointment

// Keep @factoryMethod if using injectable for abstract classes
// @factoryMethod // <-- Remove if not using abstract class factories
abstract class CalendarRepository {
  // --- Note Methods ---
  Future<List<CalendarNote>> getNotesForDate(DateTime date);
  Future<CalendarNote> addNote(CalendarNote note);
  Future<void> deleteNote(String noteId); // Changed parameter type
  Future<List<CalendarNote>> getNotesForMonth(DateTime month);
  Future<List<CalendarNote>> getCalendarNotesBetween( DateTime start, DateTime end);

  // --- Appointment Methods (Added/Updated) ---
  /// Fetches appointments for a specific date (for the logged-in user).
  Future<List<Appointment>> getAppointmentsForDate(DateTime date); // New method
  Future<List<Appointment>> getAppointmentsForMonth(DateTime month); // Keep existing
  /// Fetches appointments within a date range (for the logged-in user).
  Future<List<Appointment>> getAppointmentsForDateRange(DateTime start, DateTime end); // Keep existing

  // --- Actions (Keep if calendar screen needs to add/modify appointments) ---
  Future<Appointment> addAppointment(Appointment appointment);
  Future<void> updateAppointment(Appointment appointment);
  Future<void> deleteAppointment(String appointmentId);
}