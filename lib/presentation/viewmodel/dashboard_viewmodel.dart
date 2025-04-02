import 'package:flutter/cupertino.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:mama_care/domain/usecases/dashboard_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import '../../domain/entities/user_model.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardUseCase _dashboardUseCase;
  final DatabaseHelper _databaseHelper;

  UserModel? _user;
  PregnancyDetails? _pregnancyDetails;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardViewModel(this._dashboardUseCase, this._databaseHelper);

  // Getters
  UserModel? get user => _user;
  PregnancyDetails? get pregnancyDetails => _pregnancyDetails;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // State management methods
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Core business logic methods
  Future<void> getUserDetail() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      _user = await _dashboardUseCase.getUserDetails();
      if (_user != null) {
        await _databaseHelper.insertUserPreferences({
          'email': _user?.email,
          'name': _user?.name,
        });
      }
    } catch (e) {
      setErrorMessage("Failed to fetch user details. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  Future<void> getPregnancyDetails() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      _pregnancyDetails = await _dashboardUseCase.getPregnancyDetails();
      if (_pregnancyDetails != null) {
        DateTime dueDate;
        if (_pregnancyDetails?.startingDay != null) {
          dueDate = DateTime.fromMillisecondsSinceEpoch(_pregnancyDetails!.startingDay!);
        } else {
          dueDate = DateTime.now(); // Default fallback
        }
        
        await _databaseHelper.insertPregnancyDetail({
          'userId': _user?.id ?? '',
          'startingDay': dueDate.millisecondsSinceEpoch,
          'babyWeight': _pregnancyDetails!.babyWeight,
          'babyHeight': _pregnancyDetails!.babyHeight
        });
      }
    } catch (e) {
      setErrorMessage("Failed to fetch pregnancy details. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  void updatePregnancyDetailsFromLocal(PregnancyDetails details) {
    _pregnancyDetails = details;
    notifyListeners();
  }
}