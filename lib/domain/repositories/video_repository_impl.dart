import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/data/repositories/video_repository.dart';
import 'package:mama_care/domain/entities/video_model.dart';

@Injectable(as: VideoRepository)
@singleton
class VideoRepositoryImpl implements VideoRepository {
  final Dio _dio;
  final DatabaseHelper _databaseHelper;
  
  VideoRepositoryImpl(this._dio, this._databaseHelper);
  
  @override
  Future<List<VideoModel>> getVideos() async {
    try {
      // First try to fetch from local database
      final localVideos = await _databaseHelper.getAllVideos();
      
      if (localVideos.isNotEmpty) {
        return localVideos.map((data) => VideoModel.fromJson(data)).toList();
      }
      
      // If local is empty, fetch from API
      final response = await _dio.get('/api/videos');
      
      if (response.statusCode == 200) {
        final List<dynamic> videoData = response.data['data'];
        final videos = videoData.map((data) => VideoModel.fromJson(data)).toList();
        
        // Cache the videos locally
        for (var video in videos) {
          await _databaseHelper.insertVideo(video.toJson());
        }
        
        return videos;
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching videos: $e');
    }
  }
  
  @override
  Future<List<VideoModel>> searchVideos(String query) async {
    try {
      // Try to search locally first
      final localResults = await _databaseHelper.searchVideos(query);
      
      if (localResults.isNotEmpty) {
        return localResults.map((data) => VideoModel.fromJson(data)).toList();
      }
      
      // If no local results, search via API
      final response = await _dio.get('/api/videos/search', queryParameters: {'q': query});
      
      if (response.statusCode == 200) {
        final List<dynamic> videoData = response.data['data'];
        return videoData.map((data) => VideoModel.fromJson(data)).toList();
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching videos: $e');
    }
  }
  
  @override
  Future<VideoModel> getVideoById(String id) async {
    try {
      // Try to get from local database first
      final localVideo = await _databaseHelper.getVideoById(id);
      
      if (localVideo != null) {
        return VideoModel.fromJson(localVideo);
      }
      
      // If not found locally, get from API
      final response = await _dio.get('/api/videos/$id');
      
      if (response.statusCode == 200) {
        final videoData = response.data['data'];
        final video = VideoModel.fromJson(videoData);
        
        // Cache video locally
        await _databaseHelper.insertVideo(video.toJson());
        
        return video;
      } else {
        throw Exception('Failed to load video: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching video: $e');
    }
  }
  
  @override
  Future<VideoModel> toggleFavorite(VideoModel video) async {
    try {
      // Update the favorite status in the model
      final updatedVideo = video.copyWith(isFavorite: !video.isFavorite);
      
      // Update in local database
      await _databaseHelper.updateVideo(updatedVideo.toJson());
      
      // Sync with API if needed
      final response = await _dio.post(
        '/api/videos/${video.id}/favorite',
        data: {'isFavorite': updatedVideo.isFavorite}
      );
      
      if (response.statusCode == 200) {
        return updatedVideo;
      } else {
        // Revert local change if API update fails
        await _databaseHelper.updateVideo(video.toJson());
        throw Exception('Failed to update favorite status: ${response.statusCode}');
      }
    } catch (e) {
      // Ensure consistency with local database
      await _databaseHelper.updateVideo(video.toJson());
      throw Exception('Error toggling favorite: $e');
    }
  }
  
  @override
  Future<List<VideoModel>> getFavoriteVideos() async {
    try {
      // Get favorites from local database
      final localFavorites = await _databaseHelper.getFavoriteVideos();
      
      if (localFavorites.isNotEmpty) {
        return localFavorites.map((data) => VideoModel.fromJson(data)).toList();
      }
      
      // If no local favorites, fetch from API
      final response = await _dio.get('/api/videos/favorites');
      
      if (response.statusCode == 200) {
        final List<dynamic> videoData = response.data['data'];
        final videos = videoData.map((data) => VideoModel.fromJson(data)).toList();
        
        // Cache favorites locally
        for (var video in videos) {
          await _databaseHelper.insertVideo(video.toJson());
        }
        
        return videos;
      } else {
        throw Exception('Failed to load favorite videos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching favorite videos: $e');
    }
  }
  
  @override
  Future<List<VideoModel>> getRecommendedVideos() async {
    try {
      // Get recommendations from API (typically requires user context)
      final response = await _dio.get('/api/videos/recommended');
      
      if (response.statusCode == 200) {
        final List<dynamic> videoData = response.data['data'];
        final videos = videoData.map((data) => VideoModel.fromJson(data)).toList();
        
        // Cache locally
        for (var video in videos) {
          await _databaseHelper.insertVideo(video.toJson());
        }
        
        return videos;
      } else {
        throw Exception('Failed to load recommended videos: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to locally cached recommended videos if available
      try {
        final localRecommended = await _databaseHelper.getRecommendedVideos();
        if (localRecommended.isNotEmpty) {
          return localRecommended.map((data) => VideoModel.fromJson(data)).toList();
        }
      } catch (_) {
        // Ignore local database errors
      }
      
      throw Exception('Error fetching recommended videos: $e');
    }
  }
  
  @override
  Future<List<VideoModel>> getVideosByCategory(String category) async {
    try {
      // Try to get from local database first
      final localVideos = await _databaseHelper.getVideosByCategory(category);
      
      if (localVideos.isNotEmpty) {
        return localVideos.map((data) => VideoModel.fromJson(data)).toList();
      }
      
      // If not found locally, get from API
      final response = await _dio.get('/api/videos/category/$category');
      
      if (response.statusCode == 200) {
        final List<dynamic> videoData = response.data['data'];
        final videos = videoData.map((data) => VideoModel.fromJson(data)).toList();
        
        // Cache locally
        for (var video in videos) {
          await _databaseHelper.insertVideo(video.toJson());
        }
        
        return videos;
      } else {
        throw Exception('Failed to load videos by category: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching videos by category: $e');
    }
  }
  
  @override
  Future<VideoModel> addVideo(VideoModel video) async {
    try {
      // Send to API first
      final response = await _dio.post(
        '/api/videos',
        data: video.toJson(),
      );
      
      if (response.statusCode == 201) {
        final videoData = response.data['data'];
        final createdVideo = VideoModel.fromJson(videoData);
        
        // Cache locally
        await _databaseHelper.insertVideo(createdVideo.toJson());
        
        return createdVideo;
      } else {
        throw Exception('Failed to add video: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding video: $e');
    }
  }
  
  @override
  Future<VideoModel> updateVideo(VideoModel video) async {
    try {
      // Update via API first
      final response = await _dio.put(
        '/api/videos/${video.id}',
        data: video.toJson(),
      );
      
      if (response.statusCode == 200) {
        final videoData = response.data['data'];
        final updatedVideo = VideoModel.fromJson(videoData);
        
        // Update in local database
        await _databaseHelper.updateVideo(updatedVideo.toJson());
        
        return updatedVideo;
      } else {
        throw Exception('Failed to update video: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating video: $e');
    }
  }
  
  @override
  Future<void> deleteVideo(String id) async {
    try {
      // Delete from API first
      final response = await _dio.delete('/api/videos/$id');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Then delete from local database
        await _databaseHelper.deleteVideo(id);
      } else {
        throw Exception('Failed to delete video: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting video: $e');
    }
  }
}