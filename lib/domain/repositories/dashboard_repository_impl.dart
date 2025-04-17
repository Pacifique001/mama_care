import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/dashboard_repository.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import '../../domain/entities/pregnancy_details.dart';

@Injectable(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  final DatabaseHelper _database;
  final FirebaseMessaging _messaging;

  DashboardRepositoryImpl(this._database, this._messaging);

  @override
  Future<UserModel?> getUserDetails(String id) async {
    final results = await _database.query('users');
    return results.isEmpty ? null : UserModel.fromJson(results.first);
  }

  @override
  Future<PregnancyDetails?> getPregnancyDetails(String userId) async {
    final results = await _database.query('pregnancy_details');
    return results.isEmpty ? null : PregnancyDetails.fromJson(results.first);
  }

  @override
  Future<void> sendNotification(String message) => _messaging.sendMessage(
    to: '/topics/dashboard',
    data: {'message': message},
  );
}