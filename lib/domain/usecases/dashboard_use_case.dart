import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/dashboard_repository.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

@injectable
class DashboardUseCase {
  final DashboardRepository _dashboardRepository;

  DashboardUseCase(this._dashboardRepository);

  Future<UserModel?> getUserDetails() async {
    try {
      return await _dashboardRepository.getUserDetails();
    } catch (e) {
      print("Error fetching user details: $e");
      return null;
    }
  }

  Future<PregnancyDetails?> getPregnancyDetails() async {
    try {
      return await _dashboardRepository.getPregnancyDetails();
    } catch (e) {
      print("Error fetching pregnancy details: $e");
      return null;
    }
  }
}