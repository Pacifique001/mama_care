// lib/presentation/viewmodel/auth_viewmodel.dart

import 'dart:async';
// For jsonEncode/Decode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // For ChangeNotifier and ValueGetter
import 'package:google_sign_in/google_sign_in.dart';
// For OTP backend calls
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Custom exceptions
import 'package:mama_care/data/local/database_helper.dart'; // Local DB helper
import 'package:mama_care/domain/entities/user_model.dart'; // User entity
import 'package:mama_care/domain/entities/user_role.dart'; // Role enum
import 'package:uuid/uuid.dart'; // For generating IDs
// For ConflictAlgorithm

@injectable
class AuthViewModel extends ChangeNotifier {
  // --- Dependencies (Injected via constructor) ---
  final DatabaseHelper _databaseHelper;
  final FirebaseMessaging _firebaseMessaging;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  // --- State ---
  UserModel? _localUser;
  User? _firebaseUser;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Store the auth state stream subscription ---
  StreamSubscription<User?>? _authStateSubscription;

  // --- Constructor ---
  AuthViewModel(
    this._databaseHelper,
    this._firebaseMessaging,
    this._auth,
    this._googleSignIn,
    this._logger,
    this._firestore,
    this._uuid,
  ) {
    _logger.i('AuthViewModel initialized.');
    // Store the subscription when listening
    _authStateSubscription = _auth.authStateChanges().listen(
      _onAuthStateChanged,
    );
    _logger.i('Listening to auth state changes.');
  }

  // --- Getters ---
  UserModel? get localUser => _localUser;
  User? get currentUser => _firebaseUser;
  bool get isAuthenticated => _firebaseUser != null && _localUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserRole get userRole => _localUser?.role ?? UserRole.unknown;
  List<String> get userPermissions => _localUser?.permissions ?? [];

  // --- Private State Setters / Helpers ---
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    _logger.d('Auth loading state changed: $_isLoading');
    notifyListeners();
  }

  void _setError(String? message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    if (message != null) {
      _logger.e("AuthViewModel Error set: $message");
    } else {
      _logger.d("AuthViewModel Error cleared.");
    }
    notifyListeners();
  }

  void _clearError() => _setError(null);

  Map<String, dynamic> _handleAuthError(dynamic error) {
    String message;
    int? statusCode;
    String? errorCode;
    if (error is AuthException) {
      message = error.message;
      errorCode = error.code;
      _logger.w(
        "AuthException: ${error.message} (Code: ${error.code}, Cancelled: ${error.isCancelled})",
      );
    } else if (error is FirebaseAuthException) {
      message = _parseFirebaseError(error);
      errorCode = error.code;
      _logger.w('FirebaseAuthException: ${error.code} - $message');
    } else if (error is ArgumentError) {
      message = error.message;
      _logger.w('ArgumentError: $message');
    } else if (error is ApiException) {
      message = error.message;
      statusCode = error.statusCode;
      _logger.e(
        'ApiException: $message (Code: $statusCode)',
        error: error.cause,
        stackTrace: error.stackTrace,
      );
    } else if (error is AppException) {
      message = error.message;
      _logger.e(
        'AppException: $message',
        error: error.cause,
        stackTrace: error.stackTrace,
      );
    } else {
      message = 'An unexpected error occurred.';
      _logger.e(
        'Unhandled auth error',
        error: error,
        stackTrace: error is Error ? error.stackTrace : null,
      );
    }
    _setError(message);
    return {
      'status': 'error',
      'message': message,
      'code': errorCode,
      'statusCode': statusCode,
    };
  }

  String _parseFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 8 characters and include letters and numbers.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        _logger.e("Unknown FirebaseAuthException code: ${e.code}", error: e);
        return 'Authentication failed (${e.code}).';
    }
  }

  Map<String, dynamic> _authSuccessResponse(UserModel user) {
    return {
      'status': 'success',
      'user': user.toMap(),
      'role': userRoleToString(user.role),
      'message': 'Authentication successful',
    };
  }

  List<String> _getDefaultPermissionsForRole(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return [
          'view_profile',
          'view_appointments',
          'request_appointment',
          'view_articles',
          'view_videos',
          'view_timeline',
          'view_calendar',
        ];
      case UserRole.nurse:
        return [
          'view_profile',
          'view_assigned_patients',
          'manage_own_appointments',
          'edit_patient_notes',
          'view_articles',
          'view_videos',
        ];
      case UserRole.doctor:
        return [
          'view_profile',
          'view_all_patients',
          'manage_appointments',
          'assign_nurse',
          'manage_nurses',
          'view_reports',
          'edit_articles',
          'edit_videos',
        ];
      case UserRole.admin:
        return [
          'manage_users',
          'manage_roles',
          'manage_content',
          'view_all_data',
          'configure_settings',
        ];
      case UserRole.unknown:
        return [];
    }
  }

  // --- Auth State Change Listener ---
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _logger.i(
      'Auth state changed. Firebase user: ${firebaseUser?.uid ?? 'null'}',
    );
    _setLoading(true);
    _firebaseUser = firebaseUser;
    if (firebaseUser != null) {
      try {
        _localUser = await _fetchUserAppDataAndUpdateLocal(firebaseUser);
        if (_localUser != null) {
          await _updateUserSession(firebaseUser.uid, _localUser!.id);
          _clearError();
          _logger.i(
            "User ${firebaseUser.uid} (${_localUser!.role.name}) authenticated and synced.",
          );
        } else {
          _handleAuthError(
            AuthException("Logged in, but failed to load user data."),
          );
          await logout();
        }
      } catch (e) {
        _logger.e('Error processing auth state change', error: e);
        _handleAuthError(
          e is AppException
              ? e
              : AuthException("Failed to process login/sync.", cause: e),
        );
        _localUser = null;
        await logout();
      }
    } else {
      _localUser = null;
      _clearError();
      _logger.i("User logged out, local state cleared.");
    }
    _setLoading(false);
  }

  // --- Data Fetching & Syncing ---
  Future<UserModel> _fetchUserAppDataAndUpdateLocal(User firebaseUser) async {
    _logger.d("Fetching Firestore app data for user ${firebaseUser.uid}");
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        throw AuthException("User data not found in database.");
      }
      _logger.d("Firestore document found for ${firebaseUser.uid}. Parsing...");
      UserModel userAppData = UserModel.fromMap({
        ...docSnapshot.data()!,
        'id': docSnapshot.id,
        'firebaseId': firebaseUser.uid,
      });
      _logger.d(
        "Parsed Firestore data: Role=${userAppData.role.name}, Perms=${userAppData.permissions.length}",
      );
      final String? targetProfileImageUrl =
          (firebaseUser.photoURL != null &&
                  firebaseUser.photoURL != userAppData.profileImageUrl)
              ? firebaseUser.photoURL
              : userAppData.profileImageUrl;
      userAppData = userAppData.copyWith(
        verified: firebaseUser.emailVerified,
        profileImageUrl: () => targetProfileImageUrl,
        lastLogin: () => DateTime.now().millisecondsSinceEpoch,
      );
      _logger.d(
        "Upserting fetched/updated user data to local DB for ${userAppData.id}",
      );
      await _databaseHelper.upsertUser(userAppData.toSqliteMap());
      _logger.d("Local DB upsert complete for ${userAppData.id}");
      return userAppData;
    } on FirebaseException catch (e, s) {
      _logger.e(
        "Firestore error fetching user data for ${firebaseUser.uid}",
        error: e,
        stackTrace: s,
      );
      throw ApiException(
        "Failed to load profile from cloud.",
        cause: e,
        statusCode: e.code.hashCode,
      );
    } catch (e, s) {
      _logger.e(
        "Error processing user app data for ${firebaseUser.uid}",
        error: e,
        stackTrace: s,
      );
      throw DataProcessingException(
        "Failed to process user profile data.",
        cause: e,
      );
    }
  }

  // --- Session Management ---
  Future<void> _updateUserSession(
    String firebaseUid,
    String? localUserId,
  ) async {
    if (localUserId == null) {
      _logger.w('Cannot update session, local user ID is null.');
      return;
    }
    _logger.d(
      'Updating session info for local user: $localUserId (Firebase: $firebaseUid)',
    );
    try {
      String? fcmToken = await _firebaseMessaging.getToken();
      await _saveAndSyncFcmToken(fcmToken, localUserId, firebaseUid);
      await _databaseHelper.updateLastLogin(localUserId);
      _logger.i('User session updated successfully for $localUserId.');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to update user session for $localUserId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveAndSyncFcmToken(
    String? token,
    String localUserId,
    String firebaseUid,
  ) async {
    if (token == null) {
      _logger.w("FCM Token is null.");
      return;
    }
    _logger.d("Saving/syncing FCM token for user $localUserId / $firebaseUid");
    try {
      await _databaseHelper.transaction((txn) async {
        await _databaseHelper.saveFcmToken(token, localUserId, txn: txn);
      });
      await _updateUserFCMTokenInFirestore(firebaseUid, token);
      _logger.d("FCM token saved/synced.");
    } catch (e, stackTrace) {
      _logger.e(
        "Error saving/syncing FCM token",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _updateUserFCMTokenInFirestore(String uid, String token) async {
    try {
      _logger.d("AuthVM: Updating FCM token array in Firestore for user $uid");
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenLastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logger.d("AuthVM: Firestore FCM token updated for user $uid");
    } catch (e, stackTrace) {
      _logger.e(
        'AuthVM: Error updating FCM token array in Firestore for user $uid',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // --- Core Authentication Methods ---

  /// Logs in with email/password, relies on _onAuthStateChanged for state updates.
  Future<Map<String, dynamic>> loginWithEmail(
    String email,
    String password,
  ) async {
    _clearError();
    _setLoading(true);
    try {
      // Client-side validation
      if (!_validateEmail(email)) throw ArgumentError('Invalid email format');
      if (password.isEmpty) throw ArgumentError('Password cannot be empty');

      _logger.i('AuthVM: Attempting Firebase login for: $email');
      // Attempt Firebase Sign In
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _logger.i(
        'AuthVM: Firebase sign-in successful (listener will handle state)',
      );

      // Wait for the listener to process the auth state change and load data
      bool success = await _waitForAuthenticationState(email);

      // Check results after waiting
      if (success) {
        _setLoading(false); // Stop loading indicator
        return _authSuccessResponse(
          _localUser!,
        ); // Return success map with user data
      } else {
        _setLoading(false); // Stop loading indicator
        // If success is false, an error likely occurred in the listener or timed out
        return _handleAuthError(
          _errorMessage ??
              AuthException("Login completed but failed to load user data."),
        );
      }
    } on FirebaseAuthException catch (e) {
      _setLoading(false); // Stop loading on direct auth error
      return _handleAuthError(e); // Handle specific Firebase errors
    } catch (e) {
      // Catch validation or other unexpected errors during the process
      _logger.e('Email login process failed', error: e);
      _setLoading(false); // Stop loading
      return _handleAuthError(e);
    }
  }

  /// Signs in with Google, relies on _onAuthStateChanged for state updates.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _clearError();
    _setLoading(true);
    try {
      _logger.i('AuthVM: Attempting Google Sign-In...');
      // Start Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        _logger.w('AuthVM: Google Sign-In cancelled.');
        _setLoading(false);
        return {'status': 'cancelled', 'message': 'Sign in cancelled'};
      }
      // Get auth tokens from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _logger.i('AuthVM: Signing into Firebase with Google credential...');
      // Sign in to Firebase with the Google credential
      await _auth.signInWithCredential(credential);
      _logger.i(
        'AuthVM: Firebase Google sign-in successful (listener will handle state)',
      );

      // Wait for the listener to process the auth state change
      bool success = await _waitForAuthenticationState(
        googleUser.email,
      ); // Email is non-null if googleUser isn't null
      if (success) {
        _setLoading(false);
        return _authSuccessResponse(_localUser!);
      } else {
        _setLoading(false);
        return _handleAuthError(
          _errorMessage ??
              AuthException(
                "Google Sign-In completed but failed to load user data.",
              ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Handle errors during Firebase sign-in with credential
      _logger.w(
        'AuthVM: FirebaseAuthException during Google Sign-In',
        error: e,
      );
      await _googleSignIn.signOut().catchError(
        (_) {},
      ); // Attempt sign out on failure
      _setLoading(false);
      return _handleAuthError(e);
    } catch (e, stackTrace) {
      // Handle errors during Google Sign-In process itself or waiting
      _logger.e(
        'Google Sign-In process failed',
        error: e,
        stackTrace: stackTrace,
      );
      await _googleSignIn.signOut().catchError(
        (_) {},
      ); // Attempt sign out on failure
      _setLoading(false);
      return _handleAuthError(e);
    }
  }

  /// Signs up with email/password, creates Firestore doc, relies on _onAuthStateChanged.
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
    String? profileImageUrl,
    UserRole initialRole = UserRole.patient,
  }) async {
    _clearError();
    _setLoading(true);
    User? firebaseUser; // To hold created user for potential cleanup
    try {
      // Client-side validations
      if (!_validateEmail(email)) throw ArgumentError('Invalid email format');
      if (!_validatePassword(password)) {
        throw ArgumentError('Password validation failed.');
      }
      if (name.trim().isEmpty) throw ArgumentError('Name cannot be empty');

      _logger.i(
        'AuthVM: Attempting Firebase account creation for: $email with role: ${initialRole.name}',
      );
      // 1. Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw AuthException('Firebase user creation failed unexpectedly.');
      }
      _logger.i('AuthVM: Firebase account created: ${firebaseUser.uid}');

      // 2. Update Firebase Auth Profile (Display Name, Photo URL) - Best effort
      try {
        await firebaseUser.updateDisplayName(name.trim());
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          await firebaseUser.updatePhotoURL(profileImageUrl);
        }
        _logger.d(
          "AuthVM: Updated Firebase Auth profile for ${firebaseUser.uid}",
        );
      } catch (e) {
        _logger.w(
          'AuthVM: Non-fatal error updating Firebase Auth profile after signup',
          error: e,
        );
      }

      // 3. Create corresponding Firestore Document in 'users' collection
      _logger.d(
        "AuthVM: Creating initial Firestore document for user ${firebaseUser.uid}",
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      // Prepare data using UserModel entity
      final newUserModelData = UserModel(
        id: firebaseUser.uid, // Use Auth UID as primary ID
        firebaseId: firebaseUser.uid,
        email: email.trim().toLowerCase(), // Store lowercase email
        name: name.trim(),
        phoneNumber:
            phoneNumber?.trim().isEmpty ?? true
                ? null
                : phoneNumber!.trim(), // Store null if empty
        profileImageUrl:
            profileImageUrl ??
            firebaseUser
                .photoURL, // Use provided or fallback from Auth (if updated)
        verified:
            firebaseUser
                .emailVerified, // Should be false from email/pass signup
        createdAt: now,
        lastLogin: now, // Set initial login time
        role: initialRole, // Assign role passed in
        permissions: _getDefaultPermissionsForRole(
          initialRole,
        ), // Get default perms
        password: null,
        syncStatus: 0,
        lastSynced: now, // Initial sync state
      );
      // Save to Firestore using the UserModel's toMap method
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(newUserModelData.toMap());
      _logger.i(
        "AuthVM: Firestore document created for ${firebaseUser.uid} with role ${initialRole.name}",
      );

      // 4. Send Verification Email (Best effort, don't block success for this)
      try {
        await firebaseUser.sendEmailVerification();
        _logger.i("AuthVM: Verification email sent to $email.");
      } catch (e) {
        _logger.w("AuthVM: Failed to send verification email.", error: e);
      }

      // 5. Return success immediately. The _onAuthStateChanged listener will handle
      //    updating the local state (_localUser) and local DB based on the new Firebase user.
      _setLoading(false);
      return {
        'status': 'success',
        'message':
            'Signup successful! Please check your email for verification.',
        'userId': firebaseUser.uid,
      };
    } on FirebaseAuthException catch (e) {
      _setLoading(false); // Stop loading on Firebase specific error
      return _handleAuthError(e); // Handle known Firebase errors
    } catch (e, stackTrace) {
      // Handle Firestore errors or other exceptions
      _logger.e(
        'Sign up process failed (Firestore or other)',
        error: e,
        stackTrace: stackTrace,
      );
      _setLoading(false);
      // Attempt to clean up orphaned Auth user if Firestore write failed
      if (firebaseUser != null) {
        _logger.w(
          "Attempting delete orphaned Firebase Auth user ${firebaseUser.uid} due to Firestore/other error during signup.",
        );
        // Don't await this, just fire-and-forget cleanup attempt
        firebaseUser.delete().catchError((delErr) {
          _logger.e(
            "Failed to delete orphaned auth user ${firebaseUser?.uid}",
            error: delErr,
          );
        });
      }
      return _handleAuthError(e); // Handle the error that occurred
    }
  }

  /// Logs the current user out from Firebase and Google Sign-In.
  Future<void> logout() async {
    _logger.i('AuthVM: Attempting logout...');
    _setLoading(true);
    _clearError();
    final String? wasLoggedInUser =
        _firebaseUser?.uid; // Remember who was logged in
    try {
      // Check Google Sign-In first
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        _logger.d('AuthVM: Signed out from Google Sign-In.');
      }
      // Sign out from Firebase Auth
      await _auth.signOut();
      // The _onAuthStateChanged listener will automatically be triggered with null,
      // clearing _firebaseUser, _localUser and setting _isLoading = false.
      _logger.i('AuthVM: Firebase sign out requested successfully.');
    } catch (e, stackTrace) {
      _logger.e('AuthVM: Logout failed', error: e, stackTrace: stackTrace);
      // Force clear state even if signout API call failed, as user might be in inconsistent state
      _localUser = null;
      _firebaseUser = null;
      _handleAuthError(AuthException("Logout failed.", cause: e));
      _setLoading(false); // Ensure loading stops on explicit error here
    } finally {
      // Normally loading is set false by listener, but add check here for safety
      // in case listener doesn't fire after error or signout call fails silently.
      if (_isLoading && _firebaseUser == null && wasLoggedInUser != null) {
        _logger.w("AuthVM: Forcing loading state false after logout attempt.");
        _setLoading(false);
      }
    }
  }

  // --- Validation ---
  bool _validateEmail(String email) => RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  ).hasMatch(email);
  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    return hasLetter && hasNumber;
  }

  // --- OTP Methods (Placeholders - Implement Backend Calls) ---
  Future<Map<String, dynamic>> verifyEmailOTP(String email, String otp) async {
    _clearError();
    _setLoading(true);
    _logger.i(
      "AuthVM: Attempting to verify OTP $otp for $email via backend...",
    );
    // Simulate network call for placeholder
    await Future.delayed(const Duration(milliseconds: 1200));
    try {
      // final url = Uri.parse('YOUR_BACKEND_VERIFY_OTP_URL'); // Replace
      // final response = await http.post(url, headers: {...}, body: jsonEncode({'email': email, 'otp': otp}));
      // if (response.statusCode == 200) return {'status': 'success', 'message': 'OTP verified.'};
      // else return _handleAuthError(ApiException("OTP Verification Failed", statusCode: response.statusCode));

      _logger.w("verifyEmailOTP is using placeholder logic!");
      if (otp == "123456") {
        return {'status': 'success', 'message': 'OTP verified successfully.'};
      } else {
        return _handleAuthError(
          AuthException("Invalid OTP.", code: "invalid-otp"),
        );
      }
    } catch (e) {
      return _handleAuthError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> sendEmailOTP(String email) async {
    _clearError();
    _setLoading(true);
    _logger.i("AuthVM: Attempting to send OTP to $email via backend...");
    try {
      if (!_validateEmail(email)) throw ArgumentError("Invalid email format.");
      // final url = Uri.parse('YOUR_BACKEND_SEND_OTP_URL'); // Replace
      // final response = await http.post(url, headers: {...}, body: jsonEncode({'email': email}));
      // if (response.statusCode == 200) return {'status': 'success', 'message': 'OTP sent.'};
      // else return _handleAuthError(ApiException("Failed to send OTP", statusCode: response.statusCode));

      await Future.delayed(
        const Duration(milliseconds: 1500),
      ); // Simulate backend call
      _logger.w("sendEmailOTP is using placeholder logic!");
      return {
        'status': 'success',
        'message': 'OTP sent request submitted (placeholder). Use 123456.',
      };
    } catch (e) {
      return _handleAuthError(e);
    } finally {
      _setLoading(false);
    }
  }

  // --- Local Preferences ---
  Future<String?> getSavedEmail() async {
    try {
      return await _databaseHelper.getPreference('saved_email');
    } catch (e) {
      _logger.e("Failed to get saved email", error: e);
      return null;
    }
  }

  Future<void> saveEmail(String email) async {
    if (!_validateEmail(email)) return;
    try {
      await _databaseHelper.savePreference('saved_email', email);
      _logger.d("Saved email preference.");
    } catch (e) {
      _logger.e("Failed to save email preference", error: e);
    }
  }

  // --- Session Validation ---
  Future<UserModel?> validateSession(String sessionId) =>
      _databaseHelper.validateSession(sessionId);

  // --- Admin/Doctor Actions (Placeholder) ---
  Future<void> updateNursePermissions(
    String nurseUserId,
    List<String> newPermissions,
  ) async {
    _logger.i(
      "Placeholder: Requesting permissions update for nurse $nurseUserId",
    );
    if (userRole != UserRole.doctor && userRole != UserRole.admin) {
      _setError(
        "Permission Denied: Only authorized users can update permissions.",
      );
      return;
    }
    if (nurseUserId == _localUser?.id) {
      _setError("Cannot modify your own permissions here.");
      return;
    } // Prevent self-modification?

    _setLoading(true);
    _clearError();
    await Future.delayed(const Duration(seconds: 1)); // Simulate async work
    try {
      // TODO: Implement actual Firestore update via Repository/UseCase
      // await locator<AdminUseCase>().updateUserPermissions(nurseUserId, newPermissions);
      _logger.i(
        "Placeholder: Permissions update action complete for nurse $nurseUserId",
      );
      // Optionally trigger a refresh of user data if needed
    } catch (e) {
      _handleAuthError(e); // Use central error handler
    } finally {
      _setLoading(false);
    }
  }

  // --- Helper to wait for listener ---
  Future<bool> _waitForAuthenticationState(
    String expectedEmail, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _logger.d(
      "Waiting for auth state listener to process user $expectedEmail...",
    );
    try {
      // Wait until isLoading is false OR an error is set OR user is authenticated with correct email
      await Future.doWhile(() async {
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Check periodically
        if (_localUser != null &&
            _localUser!.email.toLowerCase() == expectedEmail.toLowerCase()) {
          return false; // Stop: Success
        }
        if (_errorMessage != null) {
          _logger.w("Listener produced error while waiting: $_errorMessage");
          return false;
        } // Stop: Error
        return _isLoading ||
            _firebaseUser ==
                null; // Continue waiting if processing or not yet authed
      }).timeout(timeout);

      // Check final state after wait/timeout
      bool success =
          isAuthenticated &&
          _localUser?.email.toLowerCase() == expectedEmail.toLowerCase();
      _logger.d(
        "Finished waiting for auth state for $expectedEmail. Success: $success. Error: $_errorMessage",
      );
      return success; // Return final success status
    } on TimeoutException {
      _logger.e("Timed out waiting for auth state listener for $expectedEmail");
      _setError("Login timed out. Please try again.");
      return false;
    } catch (e) {
      _logger.e("Error occurred while waiting for auth state listener: $e");
      _setError("An error occurred during login.");
      return false;
    }
  }

  @override
  void dispose() {
    _logger.i(
      "Disposing AuthViewModel and cancelling auth state stream listener.",
    );
    _authStateSubscription?.cancel(); // Cancel the stream subscription
    super.dispose();
  }
}
