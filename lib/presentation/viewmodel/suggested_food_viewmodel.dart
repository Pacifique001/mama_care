import 'package:flutter/material.dart';
import 'package:mama_care/domain/usecases/food_usecase.dart';
import 'package:mama_care/domain/entities/food_model.dart';

class SuggestedFoodViewModel extends ChangeNotifier {
  final FoodUseCase _foodUseCase;

  SuggestedFoodViewModel(this._foodUseCase);

  // State variables
  List<FoodModel> _suggestedFoods = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _searchQuery;

  final List<Map<String, dynamic>> _foodData = [
    // Add your food data here
  ];

  // Getters
  List<FoodModel> get suggestedFoods => _suggestedFoods;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get foodData => _foodData;

  // Load suggested foods
  Future<void> loadSuggestedFoods() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _suggestedFoods = await _foodUseCase.getSuggestedFoods();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load suggested foods: ${e.toString()}';
      _suggestedFoods = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search foods
  Future<void> searchFoods(String query) async {
    _isLoading = true;
    _searchQuery = query;
    notifyListeners();

    try {
      _suggestedFoods = await _foodUseCase.searchFoods(query);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Search failed: ${e.toString()}';
      _suggestedFoods = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh foods
  Future<void> refreshFoods() async {
    await loadSuggestedFoods();
  }

  // Get food by ID
  FoodModel? getFoodById(String id) {
    return _suggestedFoods.firstWhere((food) => food.id == id);
  }

  // Toggle food favorite status
  Future<void> toggleFavorite(String foodId) async {
    try {
      final food = _suggestedFoods.firstWhere((f) => f.id == foodId);
      final updatedFood = await _foodUseCase.toggleFavorite(food);
      
      final index = _suggestedFoods.indexWhere((f) => f.id == foodId);
      _suggestedFoods[index] = updatedFood;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update favorite status: ${e.toString()}';
      notifyListeners();
    }
  }

  // Get favorite foods
  Future<List<FoodModel>> getFavoriteFoods() async {
    try {
      return await _foodUseCase.getFavoriteFoods();
    } catch (e) {
      _errorMessage = 'Failed to get favorite foods: ${e.toString()}';
      return [];
    }
  }
} 