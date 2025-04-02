import 'package:flutter/cupertino.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:mama_care/domain/usecases/profile_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileUseCase _profileUseCase;
  final DatabaseHelper _databaseHelper;

  ProfileViewModel(this._profileUseCase, this._databaseHelper);

  PregnancyDetails? _pregnancyDetails;
  bool _isLoading = false;
  String? _errorMessage;

  PregnancyDetails? get pregnancyDetails => _pregnancyDetails;
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

  Future<void> getPregnancyDetails() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      _pregnancyDetails = await _profileUseCase.getPregnancyDetails();
      if (_pregnancyDetails != null) {
        await _databaseHelper.insertPregnancyDetail({
          'startingDay': _pregnancyDetails?.startingDay,
          'babyHeight': _pregnancyDetails?.babyHeight,
          'babyWeight': _pregnancyDetails?.babyWeight,
        });
      }
    } catch (e) {
      setErrorMessage("Failed to fetch pregnancy details. Please try again.");
    } finally {
      setLoading(false);
    }
  }
}