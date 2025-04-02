import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/calendar_repository.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';

@injectable
class CalendarUseCase {
  final CalendarRepository _repository;

  CalendarUseCase(this._repository);

  Future<CalendarNotesModel?> getCalendarNotes() async {
    try {
      return await _repository.getCalendarNotes();
    } catch (e) {
      print("Error fetching calendar notes: $e");
      return null;
    }
  }

  Future<void> addNotes(DateTime selectedDate, List<String> notesList) async {
    await _repository.addNotes(selectedDate, notesList);
  }

  Future<void> deleteNotes(DateTime selectedDate, int index) async {
    await _repository.deleteNotes(selectedDate, index);
  }
}