import 'package:flutter/material.dart';
import 'package:mama_care/domain/usecases/video_usecase.dart';
import 'package:mama_care/domain/entities/video_model.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/utils/asset_helper.dart';


class VideoListViewModel extends ChangeNotifier {
  final VideoUseCase _videoUseCase;
  final DatabaseHelper _databaseHelper;

  VideoListViewModel(this._videoUseCase, this._databaseHelper);

  // State variables
  List<VideoModel> _videos = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<VideoModel> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load videos
  Future<void> loadVideos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _videos = await _videoUseCase.getVideos();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load videos: ${e.toString()}';
      _videos = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search videos
  Future<void> searchVideos(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      _videos = await _videoUseCase.searchVideos(query);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Search failed: ${e.toString()}';
      _videos = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh videos
  Future<void> refreshVideos() async {
    await loadVideos();
  }

  // Get video by ID
  VideoModel? getVideoById(String id) {
    return _videos.firstWhere((video) => video.id == id);
  }

  // Toggle video favorite status
  Future<void> toggleFavorite(String videoId) async {
    try {
      final video = _videos.firstWhere((v) => v.id == videoId);
      final updatedVideo = await _videoUseCase.toggleFavorite(video);
      
      final index = _videos.indexWhere((v) => v.id == videoId);
      _videos[index] = updatedVideo;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update favorite status: ${e.toString()}';
      notifyListeners();
    }
  }

  // Sample videos for UI mockup/testing
  List<Map<String, dynamic>> get sampleVideos {
    return [
      {
        'title': 'Video 1',
        'description': 'Watch this video for more information',
        'image': AssetsHelper.onboardingImage1, // Example asset
      },
      // Add more videos
    ];
  }

 
}