// lib/presentation/viewmodel/nurse_dashboard_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart';
import 'package:mama_care/domain/entities/nurse.dart';
import 'package:mama_care/domain/entities/patient_summary.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/usecases/nurse_dashboard_usecase.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user ID

@injectable
class NurseDashboardViewModel extends ChangeNotifier {
  final NurseDashboardUseCase _useCase;
  final Logger _logger;
  final FirebaseAuth _auth;

  NurseDashboardViewModel(this._useCase, this._logger, this._auth) {
    _logger.i("NurseDashboardViewModel initialized.");
    // Load data immediately? Or wait for View's initState? Let's load here.
    loadInitialData();
  }

  // --- State ---
  Nurse? _nurseProfile;
  List<PatientSummary> _assignedPatients = [];
  List<Appointment> _upcomingAppointments = [];
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  Nurse? get nurseProfile => _nurseProfile;
  List<PatientSummary> get assignedPatients => List.unmodifiable(_assignedPatients);
  List<Appointment> get upcomingAppointments => List.unmodifiable(_upcomingAppointments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Private State Setters ---
  void _setLoading(bool value) { if (_isLoading == value) return; _isLoading = value; notifyListeners(); }
  void _setError(String? message) { if (_error == message) return; _error = message; if (message != null) _logger.e("NurseDashboardVM Error: $message"); notifyListeners(); }
  void _clearError() => _setError(null);

  // --- Data Loading ---
  Future<void> loadInitialData() async {
    final nurseId = _auth.currentUser?.uid;
    if (nurseId == null) {
       _logger.e("Cannot load nurse dashboard data: User not logged in.");
       _setError("Authentication required.");
       return;
    }
    _logger.i("VM: Loading initial data for nurse $nurseId");
    _setLoading(true);
    _clearError();
    try {
       // Fetch data concurrently
       final results = await Future.wait([
          _useCase.getNurseProfile(nurseId),
          _useCase.getAssignedPatients(nurseId),
          _useCase.getUpcomingAppointments(nurseId),
       ]);

       _nurseProfile = results[0] as Nurse?;
       _assignedPatients = results[1] as List<PatientSummary>? ?? [];
       _upcomingAppointments = results[2] as List<Appointment>? ?? [];

       if (_nurseProfile == null) {
          _logger.w("Nurse profile not found for $nurseId.");
          // Set error? Depends if profile is critical
          _setError("Could not load your nurse profile.");
       }
        _logger.i("VM: Initial data loaded for nurse $nurseId. Patients: ${_assignedPatients.length}, Appts: ${_upcomingAppointments.length}");

    } catch (e, s) {
        _logger.e("VM: Failed to load initial nurse data", error: e, stackTrace: s);
        _setError(e is AppException ? e.message : "Failed to load dashboard data.");
        // Clear data on error
        _nurseProfile = null;
        _assignedPatients = [];
        _upcomingAppointments = [];
    } finally {
      _setLoading(false);
    }
  }

  // --- Actions ---
  Future<void> refreshData() async {
     _logger.i("VM: Refreshing nurse dashboard data...");
     await loadInitialData(); // Re-run the initial load logic
  }

  // Add other nurse-specific actions if needed
  // e.g., mark task complete, view patient detail, etc.
}