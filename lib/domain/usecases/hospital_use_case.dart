import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/hospital_repository.dart';
import 'package:mama_care/domain/entities/place_api/hospital.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';

@injectable
class HospitalUseCase {
  final HospitalRepository _hospitalRepository;

  HospitalUseCase(this._hospitalRepository);

  Future<List<Hospital>> getHospitalList(LatLng location) async {
    return await _hospitalRepository.getHospitalList(location);
  }
}