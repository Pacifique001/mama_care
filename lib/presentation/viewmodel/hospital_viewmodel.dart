import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/domain/entities/place_api/hospital.dart'; // Assuming this path is correct
import 'package:mama_care/domain/usecases/hospital_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart'; // Needed for caching if done here
import 'package:mama_care/core/error/exceptions.dart'; // Import custom exceptions
//import 'package:collection/collection.dart';
import 'package:sqflite/sqflite.dart'; // For firstWhereOrNull

@injectable
class HospitalViewModel extends ChangeNotifier {
  // --- Dependencies ---
  final HospitalUseCase _hospitalUseCase;
  final DatabaseHelper _databaseHelper; // For local caching
  final Logger _logger;

  // --- State ---
  List<Hospital> _nearbyHospitals = []; // Store list of hospitals
  LatLng? _currentPosition;
  Set<Marker> _markers = {}; // Markers for the map
  bool _isLoading = false;
  String? _errorMessage;
  bool _locationPermissionGranted = false;
  Hospital? _selectedHospital; // Optional: Track selected hospital

  // --- Constructor ---
  HospitalViewModel(this._hospitalUseCase, this._databaseHelper, this._logger) {
    _logger.i("HospitalViewModel initialized.");
    // Optionally check permission on init, but usually better to request on demand
    // checkLocationPermission();
  }

  // --- Getters ---
  List<Hospital> get nearbyHospitals => List.unmodifiable(_nearbyHospitals);
  LatLng? get currentPosition => _currentPosition;
  Set<Marker> get markers => Set.unmodifiable(_markers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get locationPermissionGranted => _locationPermissionGranted;
  Hospital? get selectedHospital => _selectedHospital;
 

  // --- Private State Setters ---
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
     if (message != null) _logger.e("HospitalViewModel Error: $message");
    notifyListeners();
  }

  void _clearError() => _setError(null);

  void _updateMarkers() {
     _logger.d("Updating map markers based on ${_nearbyHospitals.length} hospitals.");
    final Set<Marker> newMarkers = {};
    // Add marker for current position if available
    if (_currentPosition != null) {
       newMarkers.add(
          Marker(
             markerId: const MarkerId('currentLocation'),
             position: _currentPosition!,
             icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // Different color
             infoWindow: const InfoWindow(title: 'Your Location'),
           )
       );
    }
    // Add markers for hospitals
    for (final hospital in _nearbyHospitals) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(hospital.id), // Use hospital ID
          position: LatLng(hospital.location.latitude, hospital.location.longitude),
          infoWindow: InfoWindow(
            title: hospital.name,
            snippet: hospital.address ?? 'Address not available',
            onTap: () { // Action when info window is tapped
               _logger.d("Marker InfoWindow tapped: ${hospital.name}");
               selectHospital(hospital);
            },
          ),
           onTap: () { // Action when marker itself is tapped
             _logger.d("Marker tapped: ${hospital.name}");
             // Optionally select hospital immediately on marker tap
              selectHospital(hospital);
           }
        ),
      );
    }
    _markers = newMarkers;
    notifyListeners(); // Update the UI with new markers
  }

  // --- Public Methods ---

  /// Checks and requests location permission. Updates [_locationPermissionGranted].
  Future<bool> checkAndRequestLocationPermission() async {
     _logger.i("Checking location permission...");
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
       _logger.w("Location permission denied. Requesting...");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
         _logger.e("Location permission denied by user.");
        _setError('Location permission is required to find nearby hospitals.');
        _locationPermissionGranted = false;
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
       _logger.e("Location permission denied forever.");
      _setError('Location permission is permanently denied. Please enable it in app settings.');
      _locationPermissionGranted = false;
      notifyListeners();
      return false;
    }

    _logger.i("Location permission granted.");
    _locationPermissionGranted = true;
    _clearError(); // Clear error if permission granted now
    notifyListeners();
    return true;
  }


  /// Fetches the user's current location and then nearby hospitals.
  Future<void> findUserAndNearbyHospitals() async {
    _logger.i("Attempting to find user location and nearby hospitals...");
    _setLoading(true);
    _clearError();
    _selectedHospital = null; // Clear selection

    // 1. Ensure permission first
    final hasPermission = await checkAndRequestLocationPermission();
    if (!hasPermission) {
      _setLoading(false);
      return; // Stop if permission is not granted
    }

    // 2. Get Current Location
    try {
       _logger.d("Getting current position...");
      final position = await Geolocator.getCurrentPosition(
         desiredAccuracy: LocationAccuracy.high, // Request high accuracy
         timeLimit: const Duration(seconds: 15) // Add timeout
      );
      _currentPosition = LatLng(position.latitude, position.longitude);
       _logger.i("Current position obtained: $_currentPosition");
      notifyListeners(); // Update UI potentially showing current location marker

      // 3. Fetch Hospitals based on new location
      await _fetchNearbyHospitals();

    } on TimeoutException catch (e, stackTrace){
        _logger.e("Timeout getting current location", error: e, stackTrace: stackTrace);
        _setError("Could not get your location in time. Please try again.");
    } on LocationServiceDisabledException catch(e, stackTrace) {
       _logger.e("Location services disabled", error: e, stackTrace: stackTrace);
       _setError("Location services are disabled. Please enable GPS/Location.");
    } catch (e, stackTrace) {
       _logger.e("Error getting current location", error: e, stackTrace: stackTrace);
      _setError("Failed to get current location.");
    } finally {
      _setLoading(false); // Ensure loading stops even if only location fails
    }
  }

  /// Fetches nearby hospitals based on the current [_currentPosition].
  Future<void> _fetchNearbyHospitals() async {
    if (_currentPosition == null) {
      _setError("Current location is unknown.");
      _logger.w("Cannot fetch hospitals: Current position is null.");
      return; // Don't proceed if location is missing
    }

    _logger.i("Fetching nearby hospitals for position: $_currentPosition");
    // Keep loading true if called from findUserAndNearbyHospitals
    // _setLoading(true); // No need to set again if already true
    _clearError();

    try {
      // Call UseCase
      final hospitals = await _hospitalUseCase.getHospitalList(_currentPosition!);
      _nearbyHospitals = hospitals;
       _logger.i("Fetched ${_nearbyHospitals.length} nearby hospitals.");

      // Update markers on the map
      _updateMarkers();

      // Optionally cache results locally (consider if UseCase/Repo should handle this)
      await _cacheHospitalsLocally(_nearbyHospitals);

    } on ApiException catch (e) { // Catch specific exceptions from UseCase/Repo
       _logger.e("API error fetching hospitals", error: e);
       _setError("Failed to fetch hospitals: ${e.message}");
       _nearbyHospitals = []; // Clear list on error
       _updateMarkers(); // Update markers (might just show current location)
    } on NetworkException catch (e) {
       _logger.e("Network error fetching hospitals", error: e);
       _setError("Network error: Could not reach hospital service.");
        _nearbyHospitals = [];
        _updateMarkers();
    } catch (e, stackTrace) {
       _logger.e("Unexpected error fetching hospitals", error: e, stackTrace: stackTrace);
      _setError("An unexpected error occurred while finding hospitals.");
       _nearbyHospitals = [];
       _updateMarkers();
    } finally {
      // _setLoading(false); // Loading is handled by the calling method (findUserAndNearbyHospitals)
    }
  }

  /// Caches the fetched hospital list locally.
  Future<void> _cacheHospitalsLocally(List<Hospital> hospitals) async {
    if (hospitals.isEmpty) return;
     _logger.d("Caching ${hospitals.length} hospitals locally...");
    try {
      // Using generic insert - assumes 'hospitals' table exists
      // Consider clearing old cached hospitals first?
      await _databaseHelper.transaction((txn) async {
        // Optional: Delete old cached hospitals before inserting new ones
        // await txn.delete('hospitals');
        final batch = txn.batch();
        for (final hospital in hospitals) {
           // Convert Hospital entity to Map for DB insertion
           batch.insert('hospitals', { // Ensure 'hospitals' table exists
              'id': hospital.id, // Assuming ID is part of the model/map
              'name': hospital.name,
              'address': hospital.address,
              'latitude': hospital.location.latitude,
              'longitude': hospital.location.longitude,
              'rating': hospital.rating,
              //'photoReference': hospital.photoReference, // Store photo ref if available
              'cachedAt': DateTime.now().millisecondsSinceEpoch, // Timestamp cache entry
              // Add other relevant fields
           }, conflictAlgorithm: ConflictAlgorithm.replace); // Replace existing entries
        }
        await batch.commit(noResult: true);
      });
       _logger.i("Successfully cached ${hospitals.length} hospitals.");
    } catch (e, stackTrace) {
       _logger.e("Error caching hospitals locally", error: e, stackTrace: stackTrace);
      // Don't surface this error to the user, just log it
    }
  }

  /// Selects a hospital (e.g., when a marker or list item is tapped).
  void selectHospital(Hospital hospital) {
    _logger.d("Hospital selected: ${hospital.name} (ID: ${hospital.id})");
    _selectedHospital = hospital;
    // Optionally: Move map camera to the selected hospital
    notifyListeners(); // Update UI to show details or highlight selection
  }

  /// Clears the selected hospital state.
  void clearHospitalSelection() {
    _logger.d("Clearing hospital selection.");
    _selectedHospital = null;
    notifyListeners();
  }
}