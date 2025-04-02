import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/profile_repository.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

@injectable
class ProfileUseCase {
  final ProfileRepository _repository;

  ProfileUseCase(this._repository);

  Future<UserModel?> getUserProfile() async {
    try {
      return await _repository.getUserProfile();
    } catch (e) {
      print("Error fetching user profile: $e");
      return null;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _repository.updateUserProfile(user);
  }

  Future<void> deleteUserProfile(UserModel user) async {
    await _repository.deleteUserProfile(user); // Updated to pass the user parameter
  }

  Future<void> sendProfileUpdateNotification(String message) async {
    await _repository.sendProfileUpdateNotification(message);
  }

  Future<PregnancyDetails?> getPregnancyDetails() async {
    try {
      return await _repository.getPregnancyDetails();
    } catch (e) {
      print("Error fetching pregnancy details: $e");
      return null;
    }
  }

  Future<void> savePregnancyDetails(PregnancyDetails details) async {
    await _repository.savePregnancyDetails(details);
  }
}