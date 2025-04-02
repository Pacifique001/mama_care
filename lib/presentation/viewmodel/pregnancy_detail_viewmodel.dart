import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:mama_care/domain/usecases/pregnancy_detail_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

class PregnancyDetailViewModel extends ChangeNotifier {
  final PregnancyDetailUseCase _pregnancyDetailUseCase;
  final DatabaseHelper _databaseHelper;

  PregnancyDetailViewModel(this._pregnancyDetailUseCase, this._databaseHelper);

  int? _startingDay;
  double? _babyHeight;
  double? _babyWeight;
  bool _isLoading = false;
  String? _errorMessage;

  int? get startingDay => _startingDay;
  double? get babyHeight => _babyHeight;
  double? get babyWeight => _babyWeight;
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

  Future<void> addPregnancyDetail() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      if (_startingDay != null && _babyHeight != null && _babyWeight != null) {
        final details = PregnancyDetails(
          userId: 'currentUserId', // Replace with actual user ID
          startingDay: _startingDay!,
          weeksPregnant: 0, // Replace with actual weeks pregnant
          daysPregnant: 0, // Add this parameter
          babyHeight: _babyHeight!,
          babyWeight: _babyWeight!,
          dueDate: DateTime.now(), // Ensure this is included
        );
        await _pregnancyDetailUseCase.addPregnancyDetail(details);
        await _databaseHelper.insert('pregnancy_details', details.toJson());
      }
    } catch (e) {
      setErrorMessage("Failed to add pregnancy details. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  void onBabyHeightChanged(double babyHeight) {
    _babyHeight = babyHeight;
    notifyListeners();
  }

  void onBabyWeightChanged(double babyWeight) {
    _babyWeight = babyWeight;
    notifyListeners();
  }

  void onStartingDayChanged(int startingDay) {
    _startingDay = startingDay;
    notifyListeners();
  }

  Future<void> savePregnancyDetails() async {
    try {
      final details = PregnancyDetails(
        userId: 'currentUserId', // Replace with actual user ID
        startingDay: _startingDay!,
        weeksPregnant: 0, // Replace with actual weeks pregnant
        daysPregnant: 0, // Add this parameter
        babyHeight: _babyHeight!,
        babyWeight: _babyWeight!,
        dueDate: DateTime.now(), // Ensure this is included
      );
      await _pregnancyDetailUseCase.addPregnancyDetail(details);
    } catch (e) {
      _errorMessage = 'Failed to save pregnancy details: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
