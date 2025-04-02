import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/calendar_repository.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/data/local/database_helper.dart';

@Injectable(as: CalendarRepository)
class CalendarRepositoryImpl implements CalendarRepository {
  final DatabaseHelper _databaseHelper;

  CalendarRepositoryImpl(this._databaseHelper);

  @override
  Future<CalendarNotesModel?> getCalendarNotes() async {
    try {
      final List<Map<String, dynamic>> results =
          await _databaseHelper.query('calendar_notes');
      if (results.isNotEmpty) {
        return CalendarNotesModel.fromJson(results.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get calendar notes: ${e.toString()}');
    }
  }

  @override
  Future<void> addNotes(DateTime selectedDate, List<String> notesList) async {
    try {
      final notes = CalendarNotesModel(
        date: selectedDate,
        notes: {
          (selectedDate.millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)).toString(): notesList,
       },
      );
      await _databaseHelper.insert('calendar_notes', notes.toJson());
    } catch (e) {
      throw Exception('Failed to add notes: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteNotes(DateTime selectedDate, int index) async {
    try {
      await _databaseHelper.delete(
        'calendar_notes',
        where: 'date = ?',
        whereArgs: [selectedDate.toIso8601String()],
      );
    } catch (e) {
      throw Exception('Failed to delete notes: ${e.toString()}');
    }
  }
}