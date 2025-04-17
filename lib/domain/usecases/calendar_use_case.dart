import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/data/repositories/calendar_repository.dart';
import 'package:mama_care/domain/entities/appointment.dart';

@injectable
class CalendarUseCase {
  final CalendarRepository _repository;

  CalendarUseCase(this._repository);

  Future<List<CalendarNote>> getDailyNotes(DateTime date) =>
      _repository.getNotesForDate(date);

  Future<List<CalendarNote>> getMonthlyNotes(DateTime date) =>
      _repository.getNotesForMonth(date);

  Future<CalendarNote> createNote(CalendarNote note) => _repository.addNote(note);

  Future<void> removeNote(String noteId) => _repository.deleteNote(noteId);
  
  Future<Appointment> addAppointment(Appointment appointment) =>
      _repository.addAppointment(appointment); // Add this method

  Future<List<Appointment>> getMonthlyAppointments(DateTime month) =>
       _repository.getAppointmentsForMonth(month); // Example getter
}