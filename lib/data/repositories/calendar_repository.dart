import 'package:injectable/injectable.dart';
import '../../domain/entities/calendar_notes_model.dart';

@factoryMethod
abstract class CalendarRepository {
  Future<CalendarNotesModel?> getCalendarNotes();
  Future<void> addNotes(DateTime selectedDate, List<String> notesList);
  Future<void> deleteNotes(DateTime selectedDate, int index);
}