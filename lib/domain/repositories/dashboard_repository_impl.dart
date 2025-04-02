import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/dashboard_repository.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/data/local/database_helper.dart';

@Injectable(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  final DatabaseHelper _databaseHelper;
  final FirebaseMessaging _firebaseMessaging;

  DashboardRepositoryImpl(
    this._databaseHelper,
    this._firebaseMessaging,
  );

  @override
  Future<UserModel?> getUserDetails() async {
    try {
      final results = await _databaseHelper.query('users');
      if (results.isNotEmpty) {
        return UserModel.fromJson(results.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user details: ${e.toString()}');
    }
  }

  @override
  Future<PregnancyDetails?> getPregnancyDetails() async {
    try {
      final results = await _databaseHelper.query('pregnancy_details');
      if (results.isNotEmpty) {
        return PregnancyDetails.fromJson(results.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch pregnancy details: ${e.toString()}');
    }
  }

  Future<void> sendNotification(String message) async {
    try {
      await _firebaseMessaging.sendMessage(
        to: '/topics/dashboard',
        data: {
          'message': message,
        },
      );
    } catch (e) {
      throw Exception('Failed to send notification: ${e.toString()}');
    }
  }
}