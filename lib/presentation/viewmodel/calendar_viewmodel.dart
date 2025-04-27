// lib/presentation/viewmodel/calendar_viewmodel.dart

import 'package:flutter/foundation.dart'; // Use foundation
import 'package:logger/logger.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Import Appointment
import 'package:mama_care/domain/usecases/calendar_use_case.dart'; // Import UseCase
import 'package:mama_care/core/error/exceptions.dart'; // Import custom exceptions
import 'package:mama_care/injection.dart';
import 'package:table_calendar/table_calendar.dart'; // For logger locator

class CalendarViewModel extends ChangeNotifier {
  final CalendarUseCase _useCase;
  final Logger _logger = locator<Logger>(); // Inject logger
  bool _isDisposed = false; // Track disposal status

  // --- State ---
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now(); // Separate focused date for TableCalendar
  List<CalendarNote> _notes = [];
  List<Appointment> _appointments = []; // Add list for appointments
  bool _isLoading = false;
  String? _error;

  CalendarViewModel(this._useCase) {
     _logger.i("CalendarViewModel initialized.");
     // Trigger initial load from View's initState
  }

  // --- Getters ---
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate; // Getter for focused date
  // Combine notes and appointments for the event loader
  List<dynamic> get eventsForSelectedDate => [..._notes, ..._appointments];
  // Separate getters if UI needs to display them differently
  List<CalendarNote> get notesForSelectedDate => _notes;
  List<Appointment> get appointmentsForSelectedDate => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Safely notifies listeners.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading == loading || _isDisposed) return;
    _isLoading = loading;
    _logger.d("Calendar loading state: $_isLoading");
    _safeNotifyListeners();
  }

  void _setError(String? message, {Object? error, StackTrace? stackTrace}) {
     if (_error == message || _isDisposed) return;
     _error = message;
     if (message != null) {
       _logger.e("CalendarViewModel Error: $message", error: error, stackTrace: stackTrace);
     } else {
        _logger.d("CalendarViewModel error cleared.");
     }
     _safeNotifyListeners();
  }

  /// Clears the current error message.
   void clearError() {
     _setError(null);
   }

  /// Loads both notes and appointments for the currently selected date.
  Future<void> loadDataForSelectedDate() async { // Renamed from loadNotes
    if (_isLoading || _isDisposed) return;
    _logger.i("Loading calendar data for date: $_selectedDate");
    _setLoading(true);
    clearError(); // Clear previous errors

    try {
      // Fetch notes and appointments concurrently
      final results = await Future.wait([
        _useCase.getDailyNotes(_selectedDate), // Fetch notes for the day
        _useCase.getDailyAppointments(_selectedDate), // Fetch appointments for the day
      ]);

      _notes = results[0] as List<CalendarNote>;
      _appointments = results[1] as List<Appointment>;
      _logger.i("Loaded ${_notes.length} notes and ${_appointments.length} appointments for $_selectedDate.");

    } on AuthException catch (e, s) { // Handle specific errors
       _setError("Authentication required to load calendar data.", error: e, stackTrace: s);
       _notes = []; _appointments = []; // Clear data on auth error
    } on DatabaseException catch (e, s) {
       _setError("Failed to load data from local storage.", error: e, stackTrace: s);
       _notes = []; _appointments = []; // Clear data on DB error
    } on ApiException catch (e, s) {
       _setError("Failed to load data from server: ${e.message}", error: e, stackTrace: s);
        _notes = []; _appointments = []; // Clear data on API error
    } catch (e, s) { // Catch any other errors
      _setError('Failed to load calendar data: ${e.toString()}', error: e, stackTrace: s);
       _notes = []; _appointments = []; // Clear data on unexpected error
    } finally {
      _setLoading(false);
    }
  }

  /// Updates the selected and focused dates and reloads data.
  void updateSelectedDate(DateTime selected, DateTime focused) {
    if (_selectedDate == selected && _focusedDate == focused) return; // No change

    _logger.d("Updating selected date: $selected, focused date: $focused");
    _selectedDate = selected;
    _focusedDate = focused; // Update focused date as well
    loadDataForSelectedDate(); // Reload data for the new selected date
    // Notify listeners AFTER data loading starts or finishes if you want smoother updates
    _safeNotifyListeners(); // Notify UI about date change immediately
  }

  /// Sets the calendar focus to today and reloads data.
  void goToToday() {
     final now = DateTime.now();
     updateSelectedDate(now, now); // Set both selected and focused to today
  }
  

  void updateFocusedDate(DateTime focused) {
     // Use isSameDay utility
     if (!isSameDay(_focusedDate, focused)) {
        _logger.d("Updating focused date: $focused");
        _focusedDate = focused;
        _safeNotifyListeners(); // Only notify UI about focus change
        // Do NOT reload data here, only when selected date changes
     }
  }
  // --- Note Actions ---
  Future<void> addNote(String text, String userId) async {
    if (text.trim().isEmpty) return; // Don't add empty notes

    final newNote = CalendarNote.create(
      date: _selectedDate, // Use the currently selected date
      noteText: text.trim(),
      userId: userId,
    );

    _setLoading(true);
    try {
      final createdNote = await _useCase.createNote(newNote); // UseCase now returns the full note
      _notes = [..._notes, createdNote]; // Add the created note with ID
      _logger.i("Added note: ${createdNote.id}");
      clearError();
    } catch (e, s) {
      _logger.e("Error adding note", error: e, stackTrace: s);
      _setError('Failed to save note: ${e.toString()}', error: e, stackTrace: s);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteNote(String noteId) async {
    _logger.d("Deleting note: $noteId");
    // Optional: Optimistic UI update
    // final originalNotes = List<CalendarNote>.from(_notes);
    // _notes = _notes.where((note) => note.id != noteId).toList();
    // _safeNotifyListeners();

    _setLoading(true); // Indicate activity
    try {
      await _useCase.removeNote(noteId);
      // Refresh notes for the day after deletion for consistency
      await loadDataForSelectedDate();
      // _notes = _notes.where((note) => note.id != noteId).toList(); // If not refreshing
      _logger.i("Deleted note: $noteId");
      clearError();
    } catch (e, s) {
      _logger.e("Error deleting note", error: e, stackTrace: s);
      // Optional: Revert optimistic UI update
      // _notes = originalNotes;
      _setError('Failed to delete note: ${e.toString()}', error: e, stackTrace: s);
    } finally {
      // No need to call setLoading(false) if loadDataForSelectedDate is called
       if(!_isLoading) _setLoading(false); // Set false only if refresh didn't happen
    }
  }

  // --- Appointment Actions (Example - Add only) ---
  // Assuming creation happens elsewhere usually, but could be added here
  Future<void> createAppointment(Appointment appointment) async {
     _logger.d("Adding appointment via Calendar VM");
     _setLoading(true);
     try {
        await _useCase.addAppointment(appointment);
        // Refresh data for the day to show the new appointment
        await loadDataForSelectedDate();
        clearError();
     } catch (e, s) {
       _logger.e("Error adding appointment", error: e, stackTrace: s);
       _setError("Failed to schedule appointment: ${e.toString()}", error: e, stackTrace: s);
     } finally {
       // No need to call setLoading(false) if loadDataForSelectedDate is called
        if(!_isLoading) _setLoading(false);
     }
  }


  @override
  void dispose() {
    _logger.i("Disposing CalendarViewModel.");
    _isDisposed = true;
    super.dispose();
  }
}