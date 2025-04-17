import 'package:flutter/cupertino.dart';
import '../../domain/entities/calendar_notes_model.dart';
import '../../domain/usecases/calendar_use_case.dart';

class CalendarViewModel extends ChangeNotifier {
  final CalendarUseCase _useCase;
  DateTime _selectedDate = DateTime.now();
  List<CalendarNote> _notes = [];
  bool _isLoading = false;
  String? _error;

  CalendarViewModel(this._useCase);

  DateTime get selectedDate => _selectedDate;
  List<CalendarNote> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNotes() async {
    _setLoading(true);
    try {
      _notes = await _useCase.getDailyNotes(_selectedDate);
    } catch (e) {
      _setError('Failed to load notes: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addNote(String text, String userId) async {  // Add userId parameter
  final newNote = CalendarNote.create(
    date: _selectedDate,
    noteText: text,
    userId: userId,
  );
  
  _setLoading(true);
  try {
    final id = await _useCase.createNote(newNote);
    _notes = [..._notes, newNote.copyWith(id: id.toString())];
  } catch (e) {
    _setError('Failed to save note: ${e.toString()}');
  } finally {
    _setLoading(false);
  }
}

Future<void> deleteNote(String noteId) async {  // Change parameter type to String
  _setLoading(true);
  try {
    await _useCase.removeNote(noteId);
    _notes = _notes.where((note) => note.id != noteId).toList();
  } catch (e) {
    _setError('Failed to delete note: ${e.toString()}');
  } finally {
    _setLoading(false);
  }
}

  void updateSelectedDate(DateTime newDate) {
    _selectedDate = newDate;
    loadNotes();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}