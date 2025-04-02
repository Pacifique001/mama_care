import 'package:json_annotation/json_annotation.dart';
import 'package:mama_care/domain/entities/place_api/photo.dart';
import 'package:mama_care/domain/entities/place_api/plus_code.dart';
import 'package:mama_care/domain/entities/place_api/address_component.dart';
import 'package:mama_care/domain/entities/place_api/geometry.dart';
import 'package:mama_care/domain/entities/place_api/opening_hours.dart';

part 'result.g.dart';

@JsonSerializable()
class Result {
  final String? businessStatus;
  final Geometry? geometry;
  final String? icon;
  final String? iconBackgroundColor;
  final String? iconMaskBaseUri;
  final String? name;
  final OpeningHours? openingHours;
  final List<Photo>? photos;
  final String? placeId;
  final PlusCode? plusCode;
  final double? rating;
  final String? reference;
  final String? scope;
  final List<String>? types;
  final String? vicinity;
  final String? formattedAddress;
  final String? formattedPhoneNumber;
  final List<AddressComponent>? addressComponents;
  final String? url;
  final String? adrAddress;

  Result({
    this.businessStatus,
    this.geometry,
    this.icon,
    this.iconBackgroundColor,
    this.iconMaskBaseUri,
    this.name,
    this.openingHours,
    this.photos,
    this.placeId,
    this.plusCode,
    this.rating,
    this.reference,
    this.scope,
    this.types,
    this.vicinity,
    this.formattedAddress,
    this.formattedPhoneNumber,
    this.addressComponents,
    this.url,
    this.adrAddress,
  });

  factory Result.fromJson(Map<String, dynamic> json) => _$ResultFromJson(json);

  Map<String, dynamic> toJson() => _$ResultToJson(this);
}
