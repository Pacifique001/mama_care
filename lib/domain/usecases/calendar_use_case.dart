// lib/domain/usecases/calendar_use_case.dart

import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Import Appointment
import 'package:mama_care/data/repositories/calendar_repository.dart'; // Import Repository

@injectable
class CalendarUseCase {
  final CalendarRepository _repository;

  CalendarUseCase(this._repository);

  // --- Note Methods ---
  Future<List<CalendarNote>> getDailyNotes(DateTime date) =>
      _repository.getNotesForDate(date);

  Future<List<CalendarNote>> getMonthlyNotes(DateTime date) =>
      _repository.getNotesForMonth(date);

  Future<CalendarNote> createNote(CalendarNote note) =>
      _repository.addNote(note); // Repository now returns the created note

  Future<void> removeNote(String noteId) => _repository.deleteNote(noteId);

  // --- Appointment Methods ---
  /// Fetches appointments for a specific day.
  Future<List<Appointment>> getDailyAppointments(DateTime date) =>
      _repository.getAppointmentsForDate(date); // Use the new repository method

  /// Fetches appointments for a specific month.
  Future<List<Appointment>> getMonthlyAppointments(DateTime month) =>
      _repository.getAppointmentsForMonth(month);

  /// Adds a new appointment.
  Future<Appointment> addAppointment(Appointment appointment) =>
      _repository.addAppointment(appointment);

  /// Updates an existing appointment.
  Future<void> updateAppointment(Appointment appointment) =>
      _repository.updateAppointment(appointment);

  /// Deletes an appointment by its ID.
  Future<void> deleteAppointment(String appointmentId) =>
      _repository.deleteAppointment(appointmentId);
}
