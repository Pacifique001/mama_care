// lib/data/repositories/hospital_repository_impl.dart

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/data/repositories/hospital_repository.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/entities/place_api/geometry.dart';
import 'package:mama_care/domain/entities/place_api/location.dart';
import 'package:mama_care/domain/entities/place_api/photo.dart'; // Import Photo if used
import 'package:mama_care/domain/entities/place_api/place_result.dart';
import 'package:mama_care/domain/entities/place_api/places_nearby_response.dart';
import 'package:mama_care/core/error/exceptions.dart';
import 'package:mama_care/utils/asset_helper.dart'; // Assuming API Key is here (move to env)
import 'package:sqflite/sqflite.dart'; // Import sqflite if used in _ensureFavoritesTable

@Injectable(as: HospitalRepository)
class HospitalRepositoryImpl implements HospitalRepository {
  final Dio _dio;
  final DatabaseHelper _databaseHelper;
  final Logger _logger;

  static const String _baseUrl = "https://maps.googleapis.com/maps/api/place";
  // !! IMPORTANT: Move API Key to .env !!
  static final String? _apiKey =
      dotenv.env["GOOGLE_MAPS_API_KEY"]; // Replace with secure method

  static const String _hospitalsTableName = 'favorite_hospitals';

  HospitalRepositoryImpl(this._dio, this._databaseHelper, this._logger) {
    _logger.i("HospitalRepositoryImpl initialized.");
    _ensureFavoritesTable();
  }

  Future<void> _ensureFavoritesTable() async {
    try {
      final db = await _databaseHelper.database;
      await db.execute('''
          CREATE TABLE IF NOT EXISTS $_hospitalsTableName (
            placeId TEXT PRIMARY KEY, name TEXT, address TEXT,
            latitude REAL, longitude REAL, rating REAL, imageUrl TEXT, addedAt INTEGER
          )
        ''');
      _logger.i(
        "Ensured '$_hospitalsTableName' table exists.",
      ); // Use info level
    } catch (e, s) {
      _logger.e(
        "Error ensuring favorites table exists",
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  Future<List<PlaceResult>> getHospitalList(
    LatLng latLng, {
    required double radius, // Accept the required radius parameter
  }) async {
    final url = '$_baseUrl/nearbysearch/json';
    final params = {
      'location': '${latLng.latitude},${latLng.longitude}',
      'radius':
          radius.round(), // Use the provided radius (round to integer for API)
      'type': 'hospital',
      'key': _apiKey,
      // Optional: Add fields parameter to request specific data if needed
      // 'fields': 'place_id,name,geometry,vicinity,rating,opening_hours,photos,formatted_phone_number',
    };

    _logger.d(
      "Repository: Fetching hospitals from API for ${latLng.latitude},${latLng.longitude} with radius $radius",
    );

    try {
      final response = await _dio.get(url, queryParameters: params);

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        final placesResponse = PlacesNearbyResponse.fromJson(responseData);

        if (placesResponse.status == 'OK') {
          _logger.i(
            "Repository: Found ${placesResponse.results.length} hospitals via API.",
          );
          final favorites = await getFavoriteHospitals();
          final favoriteIds = favorites.map((f) => f.placeId).toSet();
          return placesResponse.results.map((result) {
            return result.copyWith(
              isFavorite: favoriteIds.contains(result.placeId),
            );
          }).toList();
        } else if (placesResponse.status == 'ZERO_RESULTS') {
          _logger.w("Repository: Google Places API returned ZERO_RESULTS.");
          return [];
        } else {
          _logger.e(
            "Repository: Google Places API Error: ${placesResponse.status} - ${placesResponse.errorMessage}",
          );
          throw ApiException(
            placesResponse.errorMessage ??
                'Google Places API error: ${placesResponse.status}',
            statusCode: response.statusCode,
          );
        }
      } else {
        _logger.e(
          "Repository: Invalid response from Google Places API. Status: ${response.statusCode}",
        );
        throw ApiException(
          'Invalid response from Google Places API',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      _logger.e("Repository: Dio error fetching hospitals", error: e);
      _handleDioException(e);
      throw NetworkException('Network error fetching hospitals.', cause: e);
    } catch (e, stackTrace) {
      _logger.e(
        "Repository: Unexpected error fetching hospitals",
        error: e,
        stackTrace: stackTrace,
      );
      throw DataProcessingException(
        'Could not process hospital data.',
        cause: e,
      );
    }
  }

  // --- Favorite Management ---

  @override
  Future<PlaceResult> toggleFavorite(PlaceResult hospital) async {
    _logger.d(
      "Repository: Toggling favorite for Hospital ID: ${hospital.placeId}",
    );
    final db = await _databaseHelper.database;
    final bool currentlyFavorite = await _isFavorite(hospital.placeId);
    final bool newFavoriteStatus = !currentlyFavorite;

    try {
      if (newFavoriteStatus) {
        await db.insert(_hospitalsTableName, {
          'placeId': hospital.placeId,
          'name': hospital.name,
          'address': hospital.displayAddress,
          'latitude': hospital.location?.latitude,
          'longitude': hospital.location?.longitude,
          'rating': hospital.rating,
          'imageUrl':
              hospital.photos?.isNotEmpty == true
                  ? _buildPhotoUrl(hospital.photos!.first.photoReference)
                  : null,
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        _logger.i("Repository: Added ${hospital.name} to favorites.");
      } else {
        final count = await db.delete(
          _hospitalsTableName,
          where: 'placeId = ?',
          whereArgs: [hospital.placeId],
        );
        _logger.i(
          "Repository: Removed ${hospital.name} from favorites (rows deleted: $count).",
        );
      }
      return hospital.copyWith(isFavorite: newFavoriteStatus);
    } catch (e, stackTrace) {
      _logger.e(
        "Repository: Failed to toggle favorite status in DB for ${hospital.placeId}",
        error: e,
        stackTrace: stackTrace,
      );
      // Throw a more specific DatabaseException
      throw ("Could not update favorite status.", cause: e);
    }
  }

  @override
  Future<List<PlaceResult>> getFavoriteHospitals() async {
    _logger.d("Repository: Getting favorite hospitals from local DB.");
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _hospitalsTableName,
        orderBy: 'name ASC',
      );

      final favorites =
          maps
              .map(
                (map) => PlaceResult(
                  placeId: map['placeId'] as String,
                  name: map['name'] as String?,
                  vicinity: map['address'] as String?, // Map back
                  geometry:
                      (map['latitude'] != null && map['longitude'] != null)
                          ? Geometry(
                            location: Location(
                              latitude: map['latitude'] as double,
                              longitude: map['longitude'] as double,
                            ),
                          )
                          : null,
                  rating: map['rating'] as double?,
                  // Construct a basic Photo object if URL exists
                  photos:
                      map['imageUrl'] != null
                          ? [
                            Photo(
                              photoReference: map['imageUrl'],
                              height: null,
                              width: null,
                            ),
                          ]
                          : null,
                  isFavorite: true,
                  // Add other fields like openingHours if you stored them
                  // openingHours: ... map opening hours if stored ...
                ),
              )
              .toList();

      _logger.i(
        "Repository: Fetched ${favorites.length} favorite hospitals from DB.",
      );
      return favorites;
    } catch (e, stackTrace) {
      _logger.e(
        "Repository: Failed to get favorite hospitals from DB",
        error: e,
        stackTrace: stackTrace,
      );
      throw ("Could not fetch favorite hospitals.", cause: e);
    }
  }

  Future<bool> _isFavorite(String placeId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      _hospitalsTableName,
      where: 'placeId = ?',
      whereArgs: [placeId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  String _buildPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo?maxwidth=$maxWidth&photoreference=$photoReference&key=$_apiKey';
  }

  void _handleDioException(DioException e) {
    String errorType = "DioException";
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorType = "Timeout";
    } else if (e.type == DioExceptionType.cancel) {
      errorType = "Request Cancelled";
    } else if (e.type == DioExceptionType.connectionError) {
      errorType = "Connection Error";
    } else if (e.type == DioExceptionType.badResponse) {
      errorType = "Bad Response (${e.response?.statusCode})";
    }
    _logger.w(
      "$errorType: Request to ${e.requestOptions.path} failed. ${e.message}",
    );
    if (e.response != null) {
      _logger.w("Response Data: ${e.response?.data}");
    }
  }
}
