import 'package:flutter/foundation.dart'; // Use foundation for ChangeNotifier
import 'package:injectable/injectable.dart'; // Assuming injectable setup
import 'package:logger/logger.dart'; // Assuming logger is injected
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:mama_care/domain/usecases/dashboard_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/navigation/navigation_service.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException; // Import specific exceptions
import 'package:mama_care/core/error/exceptions.dart'; // Import custom exceptions

@injectable // Make ViewModel injectable
class DashboardViewModel extends ChangeNotifier {
  // --- Dependencies (Injected) ---
  final DashboardUseCase _useCase;
  final DatabaseHelper _database;
  final Logger _logger; // Inject Logger
  final FirebaseAuth _auth; // Inject FirebaseAuth to get current user ID


  // --- State ---
  UserModel? _user; // User details (can be basic if full User is in AuthViewModel)
  PregnancyDetails? _pregnancyDetails;
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  // --- Constructor ---
  DashboardViewModel(
    this._useCase,
    this._database,
    this._logger,          // Inject
    this._auth ,         
  ) {
     _logger.i("DashboardViewModel initialized.");
     // Consider triggering loadData from the View's initState/postFrameCallback
      loadData(); // Auto-load on creation (alternative to View triggering)
  }

  // --- Getters ---
  UserModel? get user => _user;
  PregnancyDetails? get pregnancyDetails => _pregnancyDetails;

   int get currentWeek {
    // Use the private calculation method
    return _calculateWeekFromDueDate() ?? 1; // Provide default
  }
  // Return unmodifiable list to prevent external modification
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Private State Setters ---
  void _setLoading(bool value) {
    if (_isLoading == value) return; // Avoid unnecessary notifications
    _isLoading = value;
    _logger.d("Dashboard loading state: $_isLoading");
    notifyListeners();
  }

  void _setError(String? message) {
    if (_error == message) return;
    _error = message;
     if (message != null) {
       _logger.e("DashboardViewModel Error: $message");
     } else {
       _logger.d("DashboardViewModel error cleared.");
     }
    notifyListeners();
  }

  void _clearError() => _setError(null);

  // --- Core Data Loading ---

  /// Loads all essential data for the dashboard. Call this on view init.
  Future<void> loadData() async {
    _logger.i('Dashboard loading data...');
    _setLoading(true);
    _clearError();

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
        _handleError("User not authenticated.", isFatal: true);
        return;
    }

    try {
      // Run operations concurrently for faster loading
      final results = await Future.wait([
        _fetchUserDetails(currentUserId),
        _fetchPregnancyDetails(currentUserId),
         fetchAppointments(currentUserId),
      // Catch errors within Future.wait to handle partial success if needed
      // However, here we let it fail fast if any part fails.
      ]);

      // Assign results after all futures complete successfully (if needed)
      // _user = results[0] as UserModel?; // Example if fetch methods returned data
      // _pregnancyDetails = results[1] as PregnancyDetails?;
      // _appointments = results[2] as List<Appointment>? ?? [];

      _logger.i('Dashboard data loaded successfully.');

    } catch (e, stackTrace) {
       _logger.e('Dashboard data loading failed', error: e, stackTrace: stackTrace);
      _handleError(_parseError(e)); // Set parsed error message
      // Ensure state is cleared on critical load failure
      _user = null;
      _pregnancyDetails = null;
      _appointments = [];
    } finally {
      _setLoading(false); // Ensure loading state is always turned off
    }
  }

  /// Fetches user details (potentially simplified if AuthViewModel holds full User)
  Future<void> _fetchUserDetails(String userId) async {
    _logger.d('Fetching user details for $userId...');
    try {
      // Assuming useCase fetches basic details needed for dashboard display
      _user = await _useCase.getUserDetails(userId); // Pass userId
       _logger.d('User details fetched: ${_user?.name}');
      // Removed redundant saving of preferences to DB
       // notifyListeners(); // Notify implicitly via loadData completion
    } on AuthException catch(e){ // Catch specific auth errors if use case throws them
       _logger.e('Auth error fetching user details', error: e);
       rethrow; // Re-throw specific exception
    } catch (e) { // Catch other errors
       _logger.e('Failed to fetch user details', error: e);
       throw DataProcessingException("Could not load user profile.", cause: e); // Wrap in custom exception
    }
  }

  /// Fetches pregnancy details from UseCase and saves/updates local DB.
  Future<void> _fetchPregnancyDetails(String userId) async {
     _logger.d('Fetching pregnancy details for $userId...');
    try {
        // Attempt to fetch from remote/use case first
        final remoteDetails = await _useCase.getPregnancyDetails(userId); // Pass userId

        if (remoteDetails != null) {
            _logger.d('Pregnancy details fetched from source.');
            _pregnancyDetails = remoteDetails;
            // Save the fetched details to the local database
            await _database.upsertPregnancyDetail( // Use upsert method
               _pregnancyDetails!.toJson(userId) // Assuming method exists
            );
             _logger.d('Pregnancy details saved locally.');
        } else {
             _logger.w('No remote pregnancy details found, attempting local load.');
             // If no remote details, try loading from local DB as fallback
             final localDetailsMap = await _database.getPregnancyDetails(userId);
             if (localDetailsMap != null) {
                 _pregnancyDetails = PregnancyDetails.fromJson(localDetailsMap);
                 _logger.i('Loaded pregnancy details from local DB.');
             } else {
                  _logger.i('No pregnancy details found locally either.');
                  _pregnancyDetails = null; // Ensure state is null
             }
        }
         // notifyListeners(); // Notify implicitly via loadData completion
    } on DatabaseException catch(e) {
         _logger.e('Database error related to pregnancy details', error: e);
         rethrow; // Re-throw specific exception
    } catch (e) {
       _logger.e('Failed to fetch or save pregnancy details', error: e);
       throw DataProcessingException("Could not load pregnancy information.", cause: e);
    }
  }

   /// Fetches appointments (pass userId if needed)
   Future<void> fetchAppointments(String userId) async {
      _logger.d('Fetching appointments for $userId...');
     try {
        // Assuming use case might need userId for filtering
        _appointments = await _useCase.getAppointments(userId);
        _logger.d('Appointments fetched: ${_appointments.length}');
         // notifyListeners(); // Notify implicitly via loadData completion
     } catch (e) {
        _logger.e('Failed to fetch appointments', error: e);
        throw DataProcessingException("Could not load appointments.", cause: e);
     }
   }


  /// Updates the local state if details were loaded from DB initially in the View.
  /// This method can likely be removed if loadData handles the fallback correctly.
  @Deprecated("Prefer loading logic within loadData method")
  void updatePregnancyDetailsFromLocal(PregnancyDetails details) {
    if (_pregnancyDetails == null) { // Only update if not already set by fetch
        _logger.i('Updating pregnancy details in ViewModel from external source.');
        _pregnancyDetails = details;
        notifyListeners();
    }
  }

  // --- Navigation ---
  void navigateToAddAppointment() {
    _logger.d('Navigating to Add Appointment screen.');
    // Use injected navigation service
    NavigationService.navigateTo(NavigationRoutes.addAppointment);
  }

  void navigateToPregnancyDetails() {
      _logger.d('Navigating to Pregnancy Details screen.');
      NavigationService.navigateTo(NavigationRoutes.pregnancy_detail);
  }

  void navigateToRoute(String routeName, {Object? arguments}) {
      _logger.d('Navigating to route: $routeName with args: $arguments');
      NavigationService.navigateTo(routeName, arguments: arguments);
  }

  // --- Error Parsing ---
  String _parseError(dynamic error) {
     _logger.e("Parsing error for UI display", error: error);
     if (error is AppException) { // Handle custom AppExceptions first
        return error.message; // Return the user-friendly message
     }
     if (error is FirebaseAuthException) {
        // Can add specific parsing here if needed, but often AuthException is thrown
        return error.message ?? "An authentication error occurred.";
     }
     if (error is Exception) {
         return "An unexpected error occurred. Please try again."; // Generic for other Exceptions
     }
     return "An unknown error occurred."; // Fallback for non-Exception types
  }

   /// Handles errors, updating state and logging.
   void _handleError(String message, {bool isFatal = false, Object? error, StackTrace? stackTrace}) {
     _logger.e("DashboardViewModel Error: $message", error: error, stackTrace: stackTrace);
     _setError(message);
     if (isFatal) {
       // Clear sensitive/dependent data on fatal errors (like auth failure)
       _user = null;
       _pregnancyDetails = null;
       _appointments = [];
       notifyListeners(); // Ensure UI reflects cleared state
     }
     _setLoading(false); // Ensure loading is stopped
   }
   int? _calculateWeekFromDueDate() {
    final detailsDueDate = _pregnancyDetails?.dueDate; // Get dueDate safely
    if (detailsDueDate == null) return null;
    // Use standard LMP calculation assumption (280 days = 40 weeks)
    final lmpDate = detailsDueDate.subtract(const Duration(days: 280));
    final today = DateTime.now();
    // Ensure LMP is not in the future relative to today
    if (lmpDate.isAfter(today)) return 1;

    final pregnancyDuration = today.difference(lmpDate);
    // Calculate week number (add 1 because week 1 starts immediately)
    final calculatedWeek = (pregnancyDuration.inDays ~/ 7) + 1;

    // Clamp to a reasonable range (e.g., 1 to 42)
    return calculatedWeek.clamp(1, 42); // Clamp to 1-42 weeks
  }
}