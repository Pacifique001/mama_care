// lib/presentation/viewmodel/doctor_appointments_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/appointment_status.dart'; // Import Enum
import 'package:mama_care/domain/usecases/appointment_usecase.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
import 'package:mama_care/domain/entities/user_role.dart';
import 'package:mama_care/core/error/exceptions.dart';
// Removed Cloud Firestore import - Timestamp handling is in Entity/Repo now

@injectable
class DoctorAppointmentsViewModel extends ChangeNotifier {
  final AppointmentUseCase _appointmentUseCase;
  final AuthViewModel _authViewModel;
  final Logger _logger;

  // --- State ---
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;
  AppointmentStatus?
  _selectedStatusFilter; // Nullable for 'all', start with null

  // --- Getters ---
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  String? get error => _error;
  AppointmentStatus? get selectedStatusFilter => _selectedStatusFilter;

  // --- Constructor ---
  DoctorAppointmentsViewModel(
    this._appointmentUseCase,
    this._authViewModel,
    this._logger,
  ) {
    _logger.i("DoctorAppointmentsViewModel initialized");
    // Listen for authentication changes
    _authViewModel.addListener(_handleAuthChange);
    // Attempt initial load if already logged in as a doctor
    _handleAuthChange(); // Call initially to check current state
  }

  // --- Auth State Listener ---
  void _handleAuthChange() {
    final bool wasDoctor =
        _appointments.isNotEmpty ||
        _isLoading ||
        _error != null; // Heuristic: Was this VM active?
    final bool isDoctor =
        _authViewModel.isAuthenticated &&
        _authViewModel.localUser?.role == UserRole.doctor;

    if (!isDoctor && wasDoctor) {
      // User logged out or changed role - clear data
      _logger.w(
        "Auth state changed (not a logged-in doctor), clearing doctor appointments.",
      );
      _appointments = [];
      _error = null;
      _selectedStatusFilter = null; // Reset filter
      _setLoading(false); // Ensure loading stops
      notifyListeners();
    } else if (isDoctor &&
        _appointments.isEmpty &&
        !_isLoading &&
        _error == null) {
      // User is now a doctor, and we haven't loaded data yet (or cleared it)
      _logger.i(
        "Auth state shows logged-in doctor, triggering appointment load.",
      );
      loadDoctorAppointments(); // Trigger load
    } else if (isDoctor && !wasDoctor) {
      // Became a doctor but maybe data is loading or error exists, trigger load anyway if not loading
      if (!_isLoading) {
        _logger.i(
          "Auth state changed to doctor, ensuring data load is triggered.",
        );
        loadDoctorAppointments();
      }
    }
  }

  // --- Private State Setters ---
  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_error == message)
      return; // Avoid redundant notifications if message is same
    _error = message;
    if (message != null) {
      _logger.e("DoctorAppointmentsViewModel Error: $message");
    }
    // Always notify when error state changes (setting or clearing)
    notifyListeners();
  }

  /// Clears the current error message.
  void clearError() => _setError(null);

  // --- Public Methods ---

  /// Sets the status filter and triggers reloading of appointments.
  /// Pass `null` to show appointments of all statuses.
  Future<void> setStatusFilter(AppointmentStatus? status) async {
    // Check if the filter actually changed
    if (_selectedStatusFilter == status) return;

    _selectedStatusFilter = status;
    _logger.i(
      "Status filter changed to: ${_selectedStatusFilter?.name ?? 'all'}",
    );
    // Notify UI immediately about the filter change (e.g., update chip selection)
    notifyListeners();

    // Reload the appointments with the new filter
    await loadDoctorAppointments();
  }

  /// Loads appointments for the currently authenticated doctor.
  /// Applies the [_selectedStatusFilter].
  Future<void> loadDoctorAppointments() async {
    // Prevent multiple simultaneous loads
    if (_isLoading) {
      _logger.d("ViewModel: Load already in progress, skipping.");
      return;
    }

    _setLoading(true);
    _setError(null); // Clear previous errors before loading

    try {
      _logger.d(
        "ViewModel: Loading doctor appointments with status filter: ${_selectedStatusFilter?.name ?? 'all'}",
      );

      // Ensure user is authenticated and is a doctor
      final currentUser = _authViewModel.localUser;
      if (currentUser == null) {
        throw AuthException("You must be logged in to view appointments.");
      }
      if (currentUser.role != UserRole.doctor) {
        throw AuthException("Only doctors can view this appointment list.");
      }

      _logger.d(
        "ViewModel: User verified as doctor (${currentUser.id}). Fetching appointments...",
      );

      // Call the use case, passing the doctor's ID and the current status filter (which can be null)
      _appointments = await _appointmentUseCase.getDoctorAppointments(
        currentUser.id,
        status: _selectedStatusFilter,
      );

      _logger.i(
        "ViewModel: Loaded ${_appointments.length} appointments for doctor ${currentUser.id}.",
      );
      _error = null; // Explicitly clear error on success
    } on AuthException catch (e) {
      // Catch specific auth errors
      _logger.w("ViewModel: Auth error loading appointments: ${e.message}");
      _setError(e.message);
      _appointments = []; // Clear data on auth error
    } catch (e, stackTrace) {
      // Catch other potential errors (API, DB, DataProcessing)
      _logger.e(
        "ViewModel: Failed to load appointments",
        error: e,
        stackTrace: stackTrace,
      );
      if (e is ApiException ||
          e is DatabaseException ||
          e is DataProcessingException) {
        _setError(
          "Failed to load appointments. Please try again later. (${e.runtimeType})",
        );
      } else {
        _setError("An unexpected error occurred while loading appointments.");
      }
      _appointments = []; // Clear data on any error
    } finally {
      _setLoading(false); // Ensure loading indicator is turned off
    }
  }

  /// Updates the status of a specific appointment.
  Future<bool> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus,
  ) async {
    _logger.d(
      "ViewModel: Requesting status update for appointment $appointmentId to ${newStatus.name}",
    );
    _setLoading(true); // Indicate busy state
    clearError(); // Clear previous errors

    try {
      // Ensure user is still an authenticated doctor
      final currentUser = _authViewModel.localUser;
      if (currentUser == null || currentUser.role != UserRole.doctor) {
        throw AuthException("Action denied: User is not a logged-in doctor.");
      }

      // Find the appointment locally for optimistic update and checks
      final appointmentIndex = _appointments.indexWhere(
        (apt) => apt.id == appointmentId,
      );
      if (appointmentIndex == -1) {
        // Optionally: Could try fetching the appointment directly if not found locally
        // final fetchedAppointment = await _appointmentUseCase.getAppointmentById(appointmentId);
        // if (fetchedAppointment == null) { ... }
        _logger.w(
          "ViewModel: Cannot update status - Appointment $appointmentId not found in the current view model list.",
        );
        throw DataProcessingException(
          "Appointment not found in the list.",
        ); // Indicate local state issue
      }
      final appointment = _appointments[appointmentIndex];

      // --- Optional: Add Business Logic Check ---
      // Example: Prevent updating already completed/cancelled appointments
      if (appointment.status == AppointmentStatus.completed ||
          appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.declined) {
        throw InvalidOperationException(
          "Cannot update status of an appointment that is already ${appointment.status.name}.",
        );
      }
      // ------------------------------------------

      // Call the use case to persist the status change
      await _appointmentUseCase.updateAppointmentStatus(
        appointmentId,
        newStatus,
      );

      // Update local state optimistically / upon success
      _appointments[appointmentIndex] = appointment.copyWith(
        status: newStatus,
        // Assume updatedAt is handled by the backend/repository via server timestamp
      );
      _logger.i(
        "ViewModel: Successfully updated appointment $appointmentId status to ${newStatus.name}",
      );

      _setLoading(false);
      notifyListeners(); // Update UI with the changed appointment
      return true; // Indicate success
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } on DataProcessingException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } on InvalidOperationException catch (e) {
      _setError(e.message); // Show specific business logic error
      _setLoading(false);
      return false;
    } catch (e, stackTrace) {
      _logger.e(
        "ViewModel: Error updating appointment status for $appointmentId",
        error: e,
        stackTrace: stackTrace,
      );
      _setError("Failed to update status. Please try again."); // Generic error
      _setLoading(false);
      return false; // Indicate failure
    }
  }

  // --- Cleanup ---
  @override
  void dispose() {
    _logger.i("Disposing DoctorAppointmentsViewModel.");
    _authViewModel.removeListener(_handleAuthChange); // Clean up listener
    super.dispose();
  }
}
