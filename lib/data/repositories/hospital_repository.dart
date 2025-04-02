import 'dart:ffi';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/domain/entities/place_api/hospital.dart';


@factoryMethod
abstract class HospitalRepository{
  Future<List<Hospital>> getHospitalList(LatLng latLng);
}