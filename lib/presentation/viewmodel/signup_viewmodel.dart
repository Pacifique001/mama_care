import 'package:flutter/material.dart';
import 'package:mama_care/domain/usecases/signup_use_case.dart';
import 'package:mama_care/domain/entities/user_model.dart';

class SignupViewModel extends ChangeNotifier {
  final SignupUseCase _signupUseCase;

  SignupViewModel(this._signupUseCase);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> signup(String email, String password, {String name = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Generate a temporary ID before actual Firebase registration
      // This will be replaced by the actual Firebase UID after registration
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final user = UserModel(
        id: tempId,      // Adding the required 'id' parameter
        email: email,
        name: name,      // Adding the required 'name' parameter
        password: password,
      );
      
      await _signupUseCase.signup(user);
    } catch (e) {
      _errorMessage = 'Failed to sign up: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}