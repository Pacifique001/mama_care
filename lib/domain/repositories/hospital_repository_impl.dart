import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/hospital_repository.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/domain/entities/place_api/hospital.dart';


@Injectable(as: HospitalRepository)
class HospitalRepositoryImpl implements HospitalRepository {
  final Dio _dio;
  final DatabaseHelper _databaseHelper;
  final FirebaseMessaging _firebaseMessaging;

  HospitalRepositoryImpl(
    this._dio,
    this._databaseHelper,
    this._firebaseMessaging,
  );

  @override
  Future<List<Hospital>> getHospitalList(LatLng latLng) async {
    // TODO: Implement logic to fetch hospital list
    return [];
  }

  @override
  Future<void> saveHospital(Hospital hospital) async {
    try {
      await _databaseHelper.insert('hospitals', hospital.toJson());
    } catch (e) {
      throw Exception('Failed to save hospital: ${e.toString()}');
    }
  }

  @override
  Future<List<Hospital>> getSavedHospitals() async {
    try {
      final List<Map<String, dynamic>> results =
          await _databaseHelper.query('hospitals');
      return results.map((json) => Hospital.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get saved hospitals: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteHospital(String id) async {
    try {
      await _databaseHelper.delete(
        'hospitals',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete hospital: ${e.toString()}');
    }
  }

  @override
  Future<void> notifyEmergency(String hospitalId) async {
    try {
      await _firebaseMessaging.sendMessage(
        to: '/topics/hospital_$hospitalId',
        data: {
          'type': 'emergency',
          'message': 'Emergency alert from MamaCare user',
        },
      );
    } catch (e) {
      throw Exception('Failed to send emergency notification: ${e.toString()}');
    }
  }

  void _handleDioException(DioException e) {
    if (e.response != null) {
      print("Dio Error: ${e.response?.statusCode} - ${e.response?.statusMessage}");
    } else {
      print("Dio Error: ${e.message}");
    }
  }
}
