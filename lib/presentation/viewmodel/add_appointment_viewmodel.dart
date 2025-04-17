// lib/presentation/viewmodel/add_appointment_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/doctor.dart'; // <-- Import Doctor entity
import 'package:mama_care/domain/usecases/calendar_use_case.dart';
import 'package:mama_care/domain/usecases/doctor_usecase.dart'; // <-- Import/Create DoctorUseCase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

@injectable
class AddAppointmentViewModel extends ChangeNotifier {
  // --- Dependencies ---
  final CalendarUseCase _calendarUseCase; // To add appointment
  final DoctorUseCase _doctorUseCase; // To get doctors <-- ADD THIS
  final Logger _logger;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  // --- State ---
  bool _isLoading = false; // General loading state
  bool _isLoadingDoctors = false; // Specific loading for doctors
  String? _error;
  List<Doctor> _availableDoctors = []; // State for doctors list

  // --- Constructor ---
  AddAppointmentViewModel(
    this._calendarUseCase,
    this._doctorUseCase, // <-- ADD THIS
    this._logger,
    this._auth,
    this._uuid,
  ) {
    _logger.i("AddAppointmentViewModel initialized.");
    // Load doctors immediately? Or trigger from View? Let's load here.
    loadAvailableDoctors();
  }

  // --- Getters ---
  bool get isLoading => _isLoading;
  bool get isLoadingDoctors => _isLoadingDoctors;
  String? get error => _error;
  List<Doctor> get availableDoctors => List.unmodifiable(_availableDoctors);

  // --- Private State Setters ---
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
  void _setLoadingDoctors(bool value) {
     if (_isLoadingDoctors == value) return;
     _isLoadingDoctors = value;
     notifyListeners();
  }

  void _setError(String? message) {
    if (_error == message) return;
    _error = message;
    if (message != null) _logger.e("AddAppointmentViewModel Error: $message");
    notifyListeners();
  }

  void _clearError() => _setError(null);

  // --- Public Methods ---

  /// Loads the list of available doctors.
  Future<void> loadAvailableDoctors() async {
    _logger.i("VM: Loading available doctors...");
    _setLoadingDoctors(true);
    _clearError(); // Clear previous errors before loading
    try {
      // Use DoctorUseCase to fetch doctors
      _availableDoctors = await _doctorUseCase.getAvailableDoctors();
      _logger.i("VM: Loaded ${_availableDoctors.length} available doctors.");
      if (_availableDoctors.isEmpty) {
         _logger.w("VM: No doctors found.");
         // Optionally set an error/info message if no doctors are available
         // _setError("No doctors available for selection.");
      }
    } catch (e, s) {
      _logger.e("VM: Failed to load available doctors", error: e, stackTrace: s);
      _setError(e is AppException ? e.message : "Could not load doctor list.");
      _availableDoctors = []; // Ensure list is empty on error
    } finally {
      _setLoadingDoctors(false);
    }
  }


  /// Saves a new appointment. Requires reason, dateTime, and doctorId.
  Future<bool> saveAppointment({
    required String reason,
    required DateTime dateTime,
    required String doctorId,
    String? notes,
  }) async {
    _logger.i("Attempting to save appointment: '$reason' at $dateTime with Doctor ID: $doctorId");
    _setLoading(true); // Use general loading for save action
    _clearError();

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
       _handleSaveError("User not authenticated. Cannot save appointment.");
       return false;
    }
    if (reason.trim().isEmpty) {
        _handleSaveError("Reason for appointment cannot be empty.");
        return false;
    }
     if (doctorId.trim().isEmpty) {
        _handleSaveError("Doctor selection is required.");
        return false;
    }

    final newAppointment = Appointment(
      id: _uuid.v4(),
      userId: userId,
      doctorId: doctorId,
      requestedTime: dateTime,
      scheduledTime: null,
      status: AppointmentStatus.pending, // Default status
      nurseId: null,
      reason: reason.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    );

    try {
      _logger.d("Calling CalendarUseCase to add appointment: ${newAppointment.id}");
      await _calendarUseCase.addAppointment(newAppointment);
      _logger.i("Appointment saved successfully (ID: ${newAppointment.id}).");
      _setLoading(false);
      return true;

    } on DatabaseException catch (e, stackTrace) {
       _logger.e("Database error saving appointment ${newAppointment.id}", error: e, stackTrace: stackTrace);
       _handleSaveError("Failed to save appointment to local storage.");
       return false;
    } on ApiException catch (e, stackTrace) {
        _logger.e("API error saving appointment ${newAppointment.id}", error: e, stackTrace: stackTrace);
        _handleSaveError("Failed to save appointment: ${e.message}");
        return false;
    } catch (e, stackTrace) {
       _logger.e("Unexpected error saving appointment ${newAppointment.id}", error: e, stackTrace: stackTrace);
       _handleSaveError("An unexpected error occurred while saving.");
       return false;
    }
  }

  // Helper for handling save errors
  void _handleSaveError(String message) {
     _setError(message);
     _setLoading(false);
  }
}