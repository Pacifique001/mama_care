import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mama_care/domain/entities/place_api/hospital.dart';
import 'package:mama_care/domain/usecases/hospital_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';

class HospitalViewModel extends ChangeNotifier {
  final HospitalUseCase _hospitalUseCase;
  final DatabaseHelper _databaseHelper;

  HospitalViewModel(this._hospitalUseCase, this._databaseHelper);

  Hospital? _hospital;
  LatLng? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  final Set<Marker> _markers = {};

  Hospital? get hospital => _hospital;
  LatLng? get currentPosition => _currentPosition;
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

  Future<void> getHospitalList() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      if (_currentPosition != null) {
        final hospitals = await _hospitalUseCase.getHospitalList(_currentPosition!);
        if (hospitals.isNotEmpty) {
          _hospital = hospitals.first;
          await _databaseHelper.insertHospitalData({
            'name': _hospital?.name,
            'address': _hospital?.address,
            'latitude': _hospital?.location.latitude,
            'longitude': _hospital?.location.longitude,
          });
          _addHospitalToMap();
        }
      }
    } catch (e) {
      setErrorMessage("Failed to fetch hospital list. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  void onCurrentPositionChanged(LatLng? latLng) {
    _currentPosition = latLng;
    notifyListeners();
  }

  Future<void> getUserCurrentLocation() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      onCurrentPositionChanged(LatLng(position.latitude, position.longitude));
      await getHospitalList();
    } catch (e) {
      setErrorMessage("Failed to get current location. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  void _addHospitalToMap() {
    if (_hospital != null) {
      _markers.add(
        Marker(
          markerId: MarkerId(_hospital!.id),
          position: LatLng(
            _hospital!.location.latitude,
            _hospital!.location.longitude,
          ),
          infoWindow: InfoWindow(
            title: _hospital!.name,
            snippet: _hospital!.address,
          ),
        ),
      );
    }
  }
}
