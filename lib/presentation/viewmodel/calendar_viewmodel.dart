import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/usecases/calendar_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';

class CalendarViewModel extends ChangeNotifier {
  final CalendarUseCase _calendarUseCase;
  final DatabaseHelper _databaseHelper;

  CalendarViewModel(this._calendarUseCase, this._databaseHelper);

  CalendarNotesModel? _calendarNotesModel;
  bool _isLoading = false;
  DateTime? _selectedDate;
  DateTime? _focusedDate;
  List<String> _notesList = [];
  String? _errorMessage;

  CalendarNotesModel? get calendarNotesModel => _calendarNotesModel;
  bool get isLoading => _isLoading;
  DateTime? get selectedDate => _selectedDate;
  DateTime? get focusedDate => _focusedDate;
  List<String> get notesList => _notesList;
  String? get errorMessage => _errorMessage;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> getCalendarNotes() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      _calendarNotesModel = await _calendarUseCase.getCalendarNotes();
      if (_calendarNotesModel != null && _selectedDate != null) {
        // Fix: Access notes as a Map and use proper key-based access
        final key = (_selectedDate!.millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)).toString();
        _notesList = _calendarNotesModel!.notes[key] ?? [];
      }
    } catch (e) {
      setErrorMessage("Failed to fetch calendar notes. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  void onSelectedDateChanged(DateTime selectedDate) {
    _selectedDate = selectedDate;
    notifyListeners();
  }

  void onFocusedDateChanged(DateTime focusedDate) {
    _focusedDate = focusedDate;
    notifyListeners();
  }

  // Fix: Remove the parameter or update method signature to accept it
  void loadNotes() {
    if (_calendarNotesModel != null && _selectedDate != null) {
      final key = (_selectedDate!.millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)).toString();
      _notesList = _calendarNotesModel!.notes[key] ?? [];
      notifyListeners();
    }
  }

  void addNotes(String note) {
    if (_selectedDate != null) {
      _notesList.add(note);
      notifyListeners();
      // Save to data source
      _saveNotes();
    }
  }

  Future<void> _saveNotes() async {
    if (_selectedDate != null) {
      try {
        await _calendarUseCase.addNotes(_selectedDate!, _notesList);
      } catch (e) {
        setErrorMessage("Failed to save notes. Please try again.");
      }
    }
  }

  Future<void> addNote(String text) async {
    setLoading(true);
    setErrorMessage(null);

    try {
      _notesList.add(text);
      await _calendarUseCase.addNotes(_selectedDate!, _notesList);
      await _databaseHelper.insertCalendarNote({
        'date': _selectedDate?.millisecondsSinceEpoch,
        'note': text,
      });
    } catch (e) {
      setErrorMessage("Failed to add note. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteNote(int index) async {
    setLoading(true);
    setErrorMessage(null);

    try {
      String noteToDelete = _notesList[index];
      _notesList.removeAt(index);
      await _calendarUseCase.addNotes(_selectedDate!, _notesList);
      try {
         await _databaseHelper.deleteCalendarNote(int.parse(noteToDelete));
      } catch (e) {
  // Handle the error, perhaps log it or show a message
      print('Error deleting note: $e');
     }
    } catch (e) {
      setErrorMessage("Failed to delete note. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteNotes(int index) async {
    if (_notesList.isNotEmpty && index < _notesList.length) {
      _notesList.removeAt(index);
      notifyListeners();
      await _saveNotes();
    }
  }

  // Fix: Update to accept a parameter or use a different name to avoid confusion
  void loadNotesFromList(List<String>? notes) {
    _notesList = notes ?? [];
    notifyListeners();
  }

  void clearNotes() {
    _notesList.clear();
    notifyListeners();
  }
}