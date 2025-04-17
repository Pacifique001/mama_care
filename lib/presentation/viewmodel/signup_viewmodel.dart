// lib/presentation/viewmodel/signup_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/domain/entities/user_role.dart'; // Import UserRole
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // Import AuthViewModel

@injectable // Make it injectable if needed independently
class SignupViewModel extends ChangeNotifier {
  // Dependencies - Primarily needs AuthViewModel to trigger signup
  final AuthViewModel _authViewModel; // Inject AuthViewModel instance
  final Logger _logger;

  // State specific to the signup process
  bool _isSigningUp = false;
  String? _signupError;

  SignupViewModel(
    this._authViewModel, // Inject AuthViewModel
    this._logger,
  ) {
    _logger.i("SignupViewModel initialized.");
    // Listen to AuthViewModel's errors if needed for broader context
    // _authViewModel.addListener(_handleAuthViewModelChanges);
  }

  // Getters for UI binding
  bool get isSigningUp => _isSigningUp;
  String? get signupError => _signupError;

  // --- Private State Setters ---
  void _setSigningUp(bool value) {
    if (_isSigningUp == value) return;
    _isSigningUp = value;
    notifyListeners();
  }

  void _setSignupError(String? message) {
    if (_signupError == message) return;
    _signupError = message;
    if (message != null) _logger.e("SignupViewModel Error: $message");
    notifyListeners();
  }

  void _clearSignupError() => _setSignupError(null);

  /// Initiates the signup process by calling the main AuthViewModel.
  /// Returns true on success (navigation handled by AuthViewModel state), false on failure.
  Future<bool> signup({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
    String? profileImageUrl, // URL after potential upload
    UserRole initialRole = UserRole.patient, // Allow specifying role (defaults to patient)
  }) async {
    _logger.i("Signup requested for email: $email with role: ${initialRole.name}");
    _setSigningUp(true);
    _clearSignupError();

    // --- Input Validation (Can add more specific signup validation here) ---
     if (email.trim().isEmpty || password.isEmpty || name.trim().isEmpty) {
        _handleSignupError("Name, email, and password cannot be empty.");
        return false;
     }
     // Add password confirmation check if you have two password fields in UI
     // ...

    try {
      // --- Call the central AuthViewModel to handle signup ---
      final result = await _authViewModel.signUpWithEmail(
        email: email.trim(),
        password: password, // Password not trimmed usually
        name: name.trim(),
        phoneNumber: phoneNumber?.trim().isEmpty ?? true ? null : phoneNumber!.trim(),
        profileImageUrl: profileImageUrl, // Pass URL if available
        initialRole: initialRole, // Pass selected role
      );

      // Check the result from AuthViewModel
      if (result['status'] == 'success') {
        _logger.i("Signup successful via AuthViewModel for $email.");
        _setSigningUp(false); // Loading stops when AuthViewModel state changes too
        return true; // Indicate success to the View
      } else {
        // Signup failed, AuthViewModel already handled logging/setting its error
        // Set local error state based on AuthViewModel's result
        _handleSignupError(result['message'] ?? "Signup failed.");
        return false; // Indicate failure
      }
    }
    // Catch potential argument errors or other exceptions *before* calling AuthViewModel
    on ArgumentError catch (e) {
       _logger.w("Signup validation error: ${e.message}");
       _handleSignupError(e.message);
       return false;
    }
    // Catch errors specifically from the AuthViewModel call if needed,
    // though AuthViewModel's `signUpWithEmail` already returns an error map.
    // catch (e) {
    //   _logger.e("Unexpected error during signup process", error: e);
    //   _handleSignupError("An unexpected error occurred during signup.");
    //   return false;
    // }
    finally {
       // Ensure loading state is reset if not already done by success/error path
       // _setSigningUp(false); // Usually handled by success/error path or AuthVM listener
    }
  }

  // Helper to set error and stop loading
  void _handleSignupError(String message) {
     _setSignupError(message);
     _setSigningUp(false);
  }

  // Optional: Listener if SignupViewModel needs to react to AuthViewModel state changes
  // void _handleAuthViewModelChanges() {
  //   if (_authViewModel.error != null && _isSigningUp) {
  //     // If auth VM encountered an error during our signup process, reflect it
  //     _setSignupError(_authViewModel.error);
  //     _setSigningUp(false);
  //   } else if (!_authViewModel.isLoading && _isSigningUp && _signupError == null) {
  //      // If auth VM stopped loading and we were signing up without error, assume success?
  //      // This might be tricky, relying on the returned map is better.
  //   }
  // }

  // @override
  // void dispose() {
  //   // _authViewModel.removeListener(_handleAuthViewModelChanges); // Remove listener if added
  //   super.dispose();
  // }
}