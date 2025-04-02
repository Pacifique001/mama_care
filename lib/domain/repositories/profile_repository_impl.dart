import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/profile_repository.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

@Injectable(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  final DatabaseHelper _databaseHelper;
  final FirebaseMessaging _firebaseMessaging;

  ProfileRepositoryImpl(
    this._databaseHelper,
    this._firebaseMessaging,
  );

  @override
  Future<UserModel?> getUserProfile() async {
    try {
      final results = await _databaseHelper.query('users');
      if (results.isNotEmpty) {
        return UserModel.fromJson(results.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user profile: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _databaseHelper.update(
        'users',
        user.toJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      throw Exception('Failed to update user profile: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUserProfile(UserModel user) async {
    try {
      await _databaseHelper.delete(
        'users',
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      throw Exception('Failed to delete user profile: ${e.toString()}');
    }
  }

  @override
  Future<void> sendProfileUpdateNotification(String message) async {
    try {
      await _firebaseMessaging.sendMessage(
        to: '/topics/profile_updates',
        data: {
          'message': message,
        },
      );
    } catch (e) {
      throw Exception('Failed to send notification: ${e.toString()}');
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

  @override
  Future<void> savePregnancyDetails(PregnancyDetails details) async {
    try {
      await _databaseHelper.insert('pregnancy_details', details.toJson());
    } catch (e) {
      throw Exception('Failed to save pregnancy details: ${e.toString()}');
    }
  }
}