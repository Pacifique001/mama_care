// lib/presentation/viewmodel/pregnancy_detail_viewmodel.dart

import 'dart:async';
import 'package:flutter/material.dart'; // Import ChangeNotifier
import 'package:injectable/injectable.dart'; // Import injectable if using it
import 'package:logger/logger.dart';
import 'package:mama_care/domain/usecases/pregnancy_detail_use_case.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
// Removed DatabaseHelper import, assuming UseCase handles persistence
// import 'package:mama_care/data/local/database_helper.dart';

@injectable // Add if using injectable for dependency injection
class PregnancyDetailViewModel extends ChangeNotifier {
  final PregnancyDetailUseCase _pregnancyDetailUseCase;
  final AuthViewModel _authViewModel; // Inject AuthViewModel
  final Logger _logger; // Inject Logger

  // --- State Variables ---
  DateTime? _selectedStartingDate; // Store as DateTime
  double? _babyHeight;
  double? _babyWeight;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Constructor ---
  // Inject dependencies
  PregnancyDetailViewModel(
    this._pregnancyDetailUseCase,
    this._authViewModel,
    this._logger,
  ) {
    _logger.i("PregnancyDetailViewModel initialized.");
    // Optional: Listen to AuthViewModel changes if needed (e.g., auto-logout if user logs out)
    // _authViewModel.addListener(_handleAuthChange);
  }

  // --- Getters ---
  // Provide read-only access to state for the UI
  DateTime? get startingDate => _selectedStartingDate;
  double? get babyHeight => _babyHeight;
  double? get babyWeight => _babyWeight;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- State Mutators ---
  // Private helper to set loading state and notify listeners
  void _setLoading(bool value) {
    if (_isLoading == value) return; // Avoid unnecessary notifications
    _isLoading = value;
    notifyListeners();
  }

  // Private helper to set error message (doesn't notify by default, actions using it should)
  void _setErrorMessage(String? message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    if (message != null) {
      _logger.w("PregnancyDetailViewModel Error: $message");
    }
    // Notify listeners ONLY if the UI needs to react directly to the error message itself
    // Often, the calling function (like addPregnancyDetail) handles UI feedback via snackbar/dialog
    // notifyListeners();
  }

  // Public method to clear the error message (e.g., when user dismisses a banner)
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      // Notify if the UI needs to remove an error display
      // notifyListeners();
    }
  }

  // Called by the UI when the date picker changes
  void onStartingDayChanged(DateTime newDate) {
    _selectedStartingDate = newDate;
    _logger.d("Starting date selection updated: $_selectedStartingDate");
    // Optionally notify listeners if the UI needs to update immediately based on the date
    // notifyListeners();
  }

  // Called by the UI when the height field changes (or on submit)
  void onBabyHeightChanged(double height) {
    _babyHeight = height;
    _logger.d("Baby height updated: $_babyHeight");
    // Optionally notify listeners
    // notifyListeners();
  }

  // Called by the UI when the weight field changes (or on submit)
  void onBabyWeightChanged(double weight) {
    _babyWeight = weight;
    _logger.d("Baby weight updated: $_babyWeight");
    // Optionally notify listeners
    // notifyListeners();
  }

  // --- Core Logic Method ---
  /// Attempts to save the pregnancy details using the UseCase.
  /// Returns true on success, false on failure.
  Future<bool> addPregnancyDetail() async {
    // 1. Get User ID from the injected AuthViewModel
    final userId =
        _authViewModel.localUser?.id ?? _authViewModel.currentUser?.uid;

    // 2. Validate Inputs (Essential checks before proceeding)
    if (userId == null || userId.isEmpty) {
      _setErrorMessage("Cannot save details: User not identified.");
      _logger.e("addPregnancyDetail failed: User ID is null or empty.");
      return false; // Indicate failure
    }
    if (_selectedStartingDate == null) {
      _setErrorMessage("Cannot save details: Start date is missing.");
      _logger.e("addPregnancyDetail failed: _selectedStartingDate is null.");
      return false; // Indicate failure
    }
    // Check height and weight (which should have been updated via onBaby... methods)
    if (_babyHeight == null || _babyWeight == null) {
      _setErrorMessage("Cannot save details: Baby dimensions are missing.");
      _logger.e(
        "addPregnancyDetail failed: Height ($_babyHeight) or Weight ($_babyWeight) is null.",
      );
      return false; // Indicate failure
    }

    // 3. Set Loading State and Clear Errors
    _setLoading(true);
    _setErrorMessage(null); // Clear previous errors before attempting save

    try {
      // 4. Calculate Derived Values
      final DateTime startDate = _selectedStartingDate!;
      // Ensure due date calculation is accurate for your needs (280 days is standard average)
      final DateTime estimatedDueDate = startDate.add(
        const Duration(days: 280),
      );
      final Duration difference = DateTime.now().difference(startDate);
      // Ensure week calculation matches clinical standards (often starts from week 0 or 1)
      final int currentWeek = (difference.inDays / 7).floor();
      final int daysIntoWeek =
          difference.inDays % 7; // Day within the current week (0-6)

      // Ensure weeksPregnant doesn't go below 0 if start date is in future slightly
      final validatedWeek = currentWeek < 0 ? 0 : currentWeek;
      final validatedDays = currentWeek < 0 ? 0 : daysIntoWeek;

      // 5. Create Entity Object
      final details = PregnancyDetails(
        userId: userId,
        startingDay: startDate, // Pass DateTime
        weeksPregnant: validatedWeek, // Pass calculated week
        daysPregnant: validatedDays, // Pass calculated day in week
        babyHeight: _babyHeight!,
        babyWeight: _babyWeight!,
        dueDate: estimatedDueDate, // Pass calculated DateTime
      );

      _logger.d(
        "Attempting to save PregnancyDetails via UseCase: ${details.toJson()}",
      );

      // 6. Call UseCase to handle saving logic (which interacts with Repository)
      await _pregnancyDetailUseCase.addPregnancyDetail(details);

      // 7. Success State
      _logger.i(
        "Pregnancy details added successfully via UseCase for user $userId.",
      );
      _setLoading(false);
      return true; // Indicate success
    } catch (e, stackTrace) {
      // 8. Error Handling
      _logger.e(
        "Failed to add pregnancy details",
        error: e,
        stackTrace: stackTrace,
      );
      // Provide a user-friendly error message
      // You could inspect 'e' for specific error types if needed
      _setErrorMessage(
        "Failed to save pregnancy details. Please check your connection and try again.",
      );
      _setLoading(false);
      return false; // Indicate failure
    }
  }

  // --- Optional: Listener for AuthViewModel changes ---
  // void _handleAuthChange() {
  //   if (!_authViewModel.isAuthenticated && !_isLoading) {
  //     // If user logs out while this VM is active, maybe clear state or log warning
  //     _logger.w("Auth state changed to unauthenticated while PregnancyDetailViewModel is active.");
  //     // Optionally clear sensitive data:
  //     // _selectedStartingDate = null;
  //     // _babyHeight = null;
  //     // _babyWeight = null;
  //     // notifyListeners();
  //   }
  // }

  // --- Cleanup ---
  @override
  void dispose() {
    _logger.i("Disposing PregnancyDetailViewModel.");
    // Remove listener if added
    // _authViewModel.removeListener(_handleAuthChange);
    super.dispose();
  }
}
