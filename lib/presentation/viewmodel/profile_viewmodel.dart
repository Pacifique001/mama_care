import 'package:flutter/cupertino.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:mama_care/domain/usecases/profile_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ViewState { initial, loading, success, error }

class ProfileViewModel extends ChangeNotifier {
  final ProfileUseCase _useCase;
  final DatabaseHelper _database;
  final _logger = Logger();
  final FirebaseAuth _auth;
  PregnancyDetails? _pregnancyDetails;
  ViewState _viewState = ViewState.initial;
  String? _errorMessage;

  ProfileViewModel(this._useCase, this._database ,this._auth);

  PregnancyDetails? get pregnancyDetails => _pregnancyDetails;
  ViewState get viewState => _viewState;
  String? get errorMessage => _errorMessage;

  Future<void> getPregnancyDetails() async {
    await _loadData(isRefresh: false);
  }

  Future<void> refreshData() async {
    await _loadData(isRefresh: true);
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    try {
      _setViewState(ViewState.loading);
      _clearError();

      if (isRefresh) {
        // Maintain existing data during refresh
        final cachedDetails = _pregnancyDetails;
        _pregnancyDetails = null;
        notifyListeners();

        // Attempt to restore cached data if fetch fails
        try {
          _pregnancyDetails = await _useCase.getPregnancyDetails();
        } catch (e) {
          _pregnancyDetails = cachedDetails;
          rethrow;
        }
      } else {
        _pregnancyDetails = await _useCase.getPregnancyDetails();
      }

      if (_pregnancyDetails != null) {
        await _database.upsertPregnancyDetail(
          _pregnancyDetails!.toJson(isRefresh),
        );
        _setViewState(ViewState.success);
      } else {
        _setError('No pregnancy details found');
      }
    } catch (e) {
      _setError('Failed to load data: ${e.toString()}');
      // Fallback to local data if available
      await _loadCachedData();
    }
  }

  Future<void> _loadCachedData() async {
    _logger.d(
      "ProfileViewModel: Attempting to load cached pregnancy details...",
    ); // Added logging
    final userId = _auth.currentUser?.uid; // Assuming _auth is injected
    if (userId == null) {
      _logger.w(
        "ProfileViewModel: Cannot load cached data, user not authenticated.",
      );
      // Optionally set an error state here if fallback fails due to no user
      // _setError("Cannot load profile: Not logged in.");
      return;
    }

    try {
      // Corrected type declaration and method call
      // getPregnancyDetails now returns Map? not List<Map>
      final Map<String, dynamic>? localData = await _database
          .getPregnancyDetails(userId); // Pass actual userId

      if (localData != null) {
        // Check if map is not null
        _logger.i("ProfileViewModel: Found cached pregnancy details.");
        _pregnancyDetails = PregnancyDetails.fromJson(localData);
        // Don't set ViewState.success here if the initial fetch failed.
        // Let the main _loadData method handle the final state.
        // Only update the data.
        notifyListeners(); // Notify that details might have been loaded from cache
      } else {
        _logger.w(
          "ProfileViewModel: No cached pregnancy details found for user $userId.",
        );
        // Ensure details are null if nothing found in cache either
        if (_viewState != ViewState.success) {
          // Avoid clearing if success was already set
          _pregnancyDetails = null;
        }
      }
    } catch (e, stackTrace) {
      // Add stackTrace
      _logger.e(
        'Error loading cached pregnancy data',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't set error state here, let the main _loadData function handle it.
      // Just log the cache loading error.
      // If cache failure is critical, you could rethrow or set a specific cache error flag.
    }
  }

  void updateLocalPregnancyDetails(PregnancyDetails newDetails) {
    _pregnancyDetails = newDetails;
    _database.upsertPregnancyDetail(newDetails.toJson(newDetails));
    notifyListeners();
  }

  void _setViewState(ViewState state) {
    if (_viewState != state) {
      _viewState = state;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _setViewState(ViewState.error);
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _clearError();
    super.dispose();
  }
}
