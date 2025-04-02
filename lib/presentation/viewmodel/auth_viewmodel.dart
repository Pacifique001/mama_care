import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/domain/usecases/login_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/repositories/firebase_auth_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


@injectable
class AuthViewModel extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final DatabaseHelper _databaseHelper;
  final FirebaseMessaging _firebaseMessaging;
  final FirebaseAuthRepository _firebaseAuthRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _otp;

  AuthViewModel(
    this._loginUseCase,
    this._databaseHelper,
    this._firebaseMessaging,
    this._firebaseAuthRepository,
  );

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<UserCredential?> login(String email, String password) async {
    setLoading(true);
    setErrorMessage(null);

    try {
      final result = await _loginUseCase.login(email, password);
      if (result != null) {
        _user = UserModel(
          id: result.user?.uid ?? '', // Use UID from Firebase user
          name: result.user?.displayName ?? '', // Provide default empty string
          email: email,
        );
        await _databaseHelper.insertUserPreferences({
          'email': email,
          'name': _user?.name,
        });
      }
      return result;
    } on FirebaseAuthException catch (e) {
      setErrorMessage(e.message ?? "Login failed. Please try again.");
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<UserCredential?> googleLogin() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      final UserCredential? result = await _loginUseCase.googleLogin();
      if (result != null && result.user != null) {
        _user = UserModel(
          id: result.user!.uid,
          name: result.user!.displayName ?? '',
          email: result.user!.email ?? '',
        );
        await _databaseHelper.insertUserPreferences({
          'email': result.user!.email,
          'name': result.user!.displayName,
        });
      }
      return result;
    } on FirebaseAuthException catch (e) {
      setErrorMessage(e.message ?? "Google login failed. Please try again.");
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    String? profileImageUrl,
  }) async {
    setLoading(true);
    setErrorMessage(null);

    try {
      // Create user with Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userId = userCredential.user!.uid;

      // Store user data in SQLite
      await _databaseHelper.insertUser({
        'id': userId,
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'profileImageUrl': profileImageUrl,
      });

      // Initialize push notifications
      await _firebaseAuthRepository.initializePushNotifications();
    } catch (e) {
      setErrorMessage("Sign up failed: ${e.toString()}");
    } finally {
      setLoading(false);
    }
  }

  Future<void> sendEmailOTP(String email) async {
    _otp = _generateRandomOTP();

    final response = await http.post(
      Uri.parse('https://your-backend-service/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': _otp}),
    );

    if (response.statusCode == 200) {
      print('OTP sent to $email');
    } else {
      throw Exception('Failed to send OTP');
    }
  }

  Future<bool> verifyEmailOTP(String email, String otp) async {
    if (_otp == otp) {
      print('OTP verified for $email');
      return true;
    } else {
      print('Invalid OTP for $email');
      return false;
    }
  }

  String _generateRandomOTP() {
    return (100000 + (999999 - 100000) * (DateTime.now().millisecondsSinceEpoch % 1000000) / 1000000).toStringAsFixed(0);
  }

  Future<void> logout() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      await _loginUseCase.logout();
      _user = null;
      await _databaseHelper.clearUserPreferences();
    } on FirebaseAuthException catch (e) {
      setErrorMessage(e.message ?? "Logout failed. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await FirebaseAuth.instance.signInWithCredential(credential);

      final user = UserModel(
        id: result.user?.uid ?? '',
        email: result.user?.email ?? '',
        name: result.user?.displayName ?? '',
      );

      // Save user details to your database
      await _saveUserDetails(user);

      return result;
    } catch (e) {
      setErrorMessage('Failed to sign in with Google: ${e.toString()}');
      return null;
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _saveUserDetails(UserModel user) async {
    // Implement this method to save user details to your database
    await _databaseHelper.insertUser(user.toJson());
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create UserModel instance
      final user = UserModel(
        id: result.user!.uid, // Use the user ID from the result
        email: result.user!.email!,
        name: result.user!.displayName ?? '', // Provide default empty string if displayName is null
      );

      // Save user details (now calling local method)
      await _saveUserDetails(user);

      return result; // Return the UserCredential
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }
}