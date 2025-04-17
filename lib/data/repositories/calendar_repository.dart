import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/entities/appointment.dart';

@factoryMethod
abstract class CalendarRepository {
  Future<List<CalendarNote>> getNotesForDate(DateTime date);
  Future<CalendarNote> addNote(CalendarNote note);
  Future<void> deleteNote(String noteId);
  Future<List<CalendarNote>> getNotesForMonth(DateTime month);
  Future<List<CalendarNote>> getCalendarNotesBetween( DateTime start, DateTime end);

  Future<List<Appointment>> getAppointmentsForMonth(DateTime month); // Example
  Future<List<Appointment>> getAppointmentsForDateRange(DateTime start, DateTime end); // Example
  Future<Appointment> addAppointment(Appointment appointment); // Add this method
  Future<void> updateAppointment(Appointment appointment); // Example
  Future<void> deleteAppointment(String appointmentId); // Example
}