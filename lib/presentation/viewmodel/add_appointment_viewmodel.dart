// lib/presentation/viewmodel/add_appointment_viewmodel.dart

import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:injectable/injectable.dart'; // For dependency injection
import 'package:intl/intl.dart';
import 'package:logger/logger.dart'; // For logging
import 'package:mama_care/domain/entities/appointment.dart'; // Your Appointment entity
import 'package:mama_care/domain/entities/user_model.dart'; // Your User entity
import 'package:mama_care/domain/entities/user_role.dart'; // Your UserRole enum
import 'package:mama_care/domain/usecases/appointment_usecase.dart'; // UseCase for appointment logic
import 'package:mama_care/domain/usecases/doctor_usecase.dart'; // UseCase for doctor-related logic
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // To get current user state
import 'package:mama_care/data/repositories/notification_repository.dart'; // To send notifications
import 'package:mama_care/core/error/exceptions.dart'; // Your custom exceptions

@injectable // Marks class for dependency injection
class AddAppointmentViewModel extends ChangeNotifier {
  // --- Dependencies (Injected via Constructor) ---
  final AppointmentUseCase _appointmentUseCase;
  final DoctorUseCase _doctorUseCase; // UseCase to fetch doctors
  final AuthViewModel _authViewModel; // To access current user information
  final NotificationRepository
  _notificationRepository; // To trigger notifications
  final Logger _logger;

  // --- State Variables ---
  List<UserModel> _availableDoctors = []; // List to hold fetched doctors
  bool _isLoading = false; // Tracks saving appointment state
  bool _isLoadingDoctors = false; // Tracks loading state for doctor list
  String? _error; // Holds error messages for the UI

  // --- Constructor ---
  AddAppointmentViewModel(
    this._appointmentUseCase,
    this._doctorUseCase,
    this._authViewModel, // Ensure AuthViewModel is a Singleton or provided correctly
    this._notificationRepository,
    this._logger,
  ) {
    _logger.i("AddAppointmentViewModel initialized.");
    // Immediately load available doctors when the ViewModel is created
    loadAvailableDoctors();
  }

  // --- Getters ---
  // Provide read-only access to the state for the UI
  List<UserModel> get availableDoctors => List.unmodifiable(_availableDoctors);
  bool get isLoading => _isLoading; // Is an appointment currently being saved?
  bool get isLoadingDoctors =>
      _isLoadingDoctors; // Is the doctor list currently loading?
  String? get error => _error;

  // --- Private State Mutators ---
  // Helper to set the main loading state (saving appointment)
  void _setLoading(bool loading) {
    if (_isLoading == loading) return; // Avoid unnecessary notifications
    _isLoading = loading;
    notifyListeners();
  }

  // Helper to set the loading state for fetching doctors
  void _setLoadingDoctors(bool loading) {
    if (_isLoadingDoctors == loading) return;
    _isLoadingDoctors = loading;
    notifyListeners();
  }

  // Helper to set an error message and notify listeners
  void _setError(String? message) {
    // Use a separate method to allow logging/processing before notifying
    _updateErrorState(message);
  }

  // Helper to update error state and log
  void _updateErrorState(String? message) {
    if (_error == message) return; // Avoid redundant notifications
    _error = message;
    if (message != null) {
      _logger.e("AddAppointmentViewModel Error: $message");
    }
    notifyListeners(); // Notify UI when error changes
  }

  /// Clears the current error message.
  void clearError() {
    // Only notify if there was actually an error to clear
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // --- Data Loading ---

  /// Loads the list of available doctors (users with role 'doctor').
  /// Optionally filters by specialty if implemented in the UseCase/Repository.
  Future<void> loadAvailableDoctors({String? specialtyFilter}) async {
    // Prevent fetching if already loading doctors
    if (_isLoadingDoctors) return;

    _setLoadingDoctors(true);
    _setError(null); // Clear previous errors before loading

    try {
      _logger.d("ViewModel: Loading available doctors...");
      // Call the DoctorUseCase to get doctors (should return List<UserModel>)
      _availableDoctors = await _doctorUseCase.getAvailableDoctors(
        specialtyFilter: specialtyFilter,
      );
      _logger.i(
        "ViewModel: Loaded ${_availableDoctors.length} available doctors.",
      );

      // Handle the case where no doctors are found
      if (_availableDoctors.isEmpty) {
        _logger.w("ViewModel: No available doctors found matching criteria.");
        // Optionally set an informational message instead of an error
        // _setError("No doctors are currently available for booking.");
      } else {
        _error = null; // Ensure error is null on success
      }
    } catch (e, stackTrace) {
      _logger.e(
        "ViewModel: Error loading available doctors",
        error: e,
        stackTrace: stackTrace,
      );
      // Provide a user-friendly error message
      _setError("Failed to load available doctors. Please try again later.");
      _availableDoctors = []; // Ensure the list is empty on error
    } finally {
      _setLoadingDoctors(false); // Ensure loading indicator stops
    }
  }

  // --- Core Action Method ---

  /// Attempts to create and save a new appointment request.
  /// Returns the created [Appointment] object on success, otherwise returns `null`.
  /// Triggers a local notification simulation after successful creation.
  Future<Appointment?> saveAppointment({
    required String doctorId,
    required String reason,
    required DateTime dateTime,
    String? notes,
  }) async {
    // Prevent multiple save attempts simultaneously
    if (_isLoading) return null;

    _setLoading(true);
    _setError(null); // Clear previous errors

    Appointment?
    createdAppointment; // To store the successfully created appointment

    try {
      _logger.d("ViewModel: Saving appointment request -> Doctor $doctorId");

      // 1. Get current user from the injected AuthViewModel
      final currentUser = _authViewModel.localUser;
      if (currentUser == null) {
        throw AuthException("You must be logged in to request an appointment.");
      }

      // 2. Verify the current user's role (must be a patient)
      if (currentUser.role != UserRole.patient) {
        throw AuthException(
          "Action not allowed: Only patients can request appointments.",
        );
      }

      // 3. Call the Appointment UseCase to handle the creation logic
      // This UseCase fetches names and calls the repository. It returns the created Appointment.
      createdAppointment = await _appointmentUseCase.requestAppointment(
        patientId: currentUser.id, // Use the patient's ID from UserModel
        doctorId: doctorId,
        reason: reason,
        dateTime: dateTime,
        notes: notes,
      );

      _logger.i(
        "ViewModel: Appointment request successful. ID: ${createdAppointment?.id}",
      );

      // 4. Trigger Local Notification Simulation (if creation was successful)
      if (createdAppointment != null) {
        _triggerDoctorNotificationSimulation(createdAppointment);
      }

      _setLoading(false);
      return createdAppointment; // Return the created object on success

      // --- Specific Error Handling ---
    } on AuthException catch (e) {
      _logger.w("ViewModel: Auth error saving appointment - ${e.message}");
      _setError(e.message); // Set specific error message
      _setLoading(false);
      return null; // Indicate failure
    } on DataNotFoundException catch (e) {
      _logger.w(
        "ViewModel: Data not found error saving appointment - ${e.message}",
      );
      _setError(e.message); // e.g., "Selected doctor could not be found."
      _setLoading(false);
      return null;
    } on InvalidArgumentException catch (e) {
      _logger.w(
        "ViewModel: Invalid argument error saving appointment - ${e.message}",
      );
      _setError(e.message); // e.g., "Reason cannot be empty."
      _setLoading(false);
      return null;
    } on DomainException catch (e) {
      // Catch specific domain errors from UseCase
      _logger.e(
        "ViewModel: Domain error saving appointment - ${e.message}",
        error: e.cause,
      );
      _setError(e.message); // Use message from DomainException
      _setLoading(false);
      return null;
    } catch (e, stackTrace) {
      // Catch any other unexpected errors
      _logger.e(
        "ViewModel: Unexpected error saving appointment",
        error: e,
        stackTrace: stackTrace,
      );
      _setError("An unexpected error occurred. Please try again.");
      _setLoading(false);
      return null; // Indicate failure
    }
  }

  /// Simulates sending a notification to the doctor by showing a local one
  /// on the current (patient's) device using the NotificationRepository.
  void _triggerDoctorNotificationSimulation(Appointment appointment) {
    _logger.i(
      "Simulating notification to Doctor ${appointment.doctorId} for appointment ${appointment.id}",
    );
    try {
      // Use the injected NotificationRepository
      _notificationRepository.sendNotification({
        'title': 'New Appointment Request',
        'body':
            '${appointment.patientName} requested an appointment for ${DateFormat.yMd().add_jm().format(appointment.appointmentDateTime)}.', // Include date/time
        // Data payload for potential interaction if the notification was real
        'payload': {
          'type': 'appointment_request', // Helps identify notification type
          'appointmentId': appointment.id,
          'doctorId': appointment.doctorId,
          'patientId': appointment.patientId,
           'route': '/doctor/appointment/${appointment.id}' // Example target route
        },
      });
      _logger.d("Local notification simulation triggered.");
    } catch (e, s) {
      // Log error but don't interrupt the main flow
      _logger.e(
        "Error triggering local doctor notification simulation",
        error: e,
        stackTrace: s,
      );
    }
  }

  // --- Cleanup ---
  @override
  void dispose() {
    _logger.i("Disposing AddAppointmentViewModel.");
    // If listeners were added to AuthViewModel, remove them here:
    // _authViewModel.removeListener(_handleAuthViewModelChanges);
    super.dispose();
  }
} // End of AddAppointmentViewModel Class
