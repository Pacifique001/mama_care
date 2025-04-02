import 'dart:ffi';
import 'package:flutter/cupertino.dart';
import 'package:mama_care/domain/usecases/risk_detector_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/entities/risk_data.dart'; // Import the RiskData class

class RiskDetectorViewModel extends ChangeNotifier {
  final RiskDetectorUseCase _riskDetectorUseCase;
  final DatabaseHelper _databaseHelper;

  bool _isLoading = false;
  RiskData? _riskData; // Change to RiskData?
  String? _errorMessage;

  bool get isLoading => _isLoading;
  RiskData? get riskData => _riskData; // Change to RiskData?
  String? get errorMessage => _errorMessage;

  RiskDetectorViewModel(this._riskDetectorUseCase, this._databaseHelper);

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<RiskData> getRiskData(
    int age,
    int systolicBP,
    int diastolicBP,
    double bs,
    double bodyTemp,
    int heartRate,
  ) async {
    setLoading(true);
    setErrorMessage(null);

    try {
      // Create a map with the required data
      final inputData = {
        'age': age,
        'systolicBP': systolicBP,
        'diastolicBP': diastolicBP,
        'bs': bs,
        'bodyTemp': bodyTemp,
        'heartRate': heartRate,
      };

      final result = await _riskDetectorUseCase.getRiskData(inputData);
      _riskData = result;
      notifyListeners();
      return result;
    } catch (e) {
      setErrorMessage("Failed to fetch risk data. Please try again.");
      rethrow; // Let the error propagate
    } finally {
      setLoading(false);
    }
  }

  Future<void> detectRisk(Map<String, dynamic> inputData) async {
    _isLoading = true;
    notifyListeners();

    try {
      _riskData = await _riskDetectorUseCase.getRiskData(inputData);
    } catch (e) {
      _errorMessage = 'Failed to detect risk: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
