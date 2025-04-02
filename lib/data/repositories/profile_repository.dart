import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import '../../domain/entities/pregnancy_details.dart';

@factoryMethod
abstract class ProfileRepository {
  Future<UserModel?> getUserProfile();
  Future<void> updateUserProfile(UserModel user);
  Future<void> deleteUserProfile(UserModel user); // Updated method signature
  Future<void> sendProfileUpdateNotification(String message);
  Future<PregnancyDetails?> getPregnancyDetails();
  Future<void> savePregnancyDetails(PregnancyDetails details);
}