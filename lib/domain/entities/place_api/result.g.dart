// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Result _$ResultFromJson(Map<String, dynamic> json) => Result(
  businessStatus: json['businessStatus'] as String?,
  geometry:
      json['geometry'] == null
          ? null
          : Geometry.fromJson(json['geometry'] as Map<String, dynamic>),
  icon: json['icon'] as String?,
  iconBackgroundColor: json['iconBackgroundColor'] as String?,
  iconMaskBaseUri: json['iconMaskBaseUri'] as String?,
  name: json['name'] as String?,
  openingHours:
      json['openingHours'] == null
          ? null
          : OpeningHours.fromJson(json['openingHours'] as Map<String, dynamic>),
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
          .toList(),
  placeId: json['placeId'] as String?,
  plusCode:
      json['plusCode'] == null
          ? null
          : PlusCode.fromJson(json['plusCode'] as Map<String, dynamic>),
  rating: (json['rating'] as num?)?.toDouble(),
  reference: json['reference'] as String?,
  scope: json['scope'] as String?,
  types: (json['types'] as List<dynamic>?)?.map((e) => e as String).toList(),
  vicinity: json['vicinity'] as String?,
  formattedAddress: json['formattedAddress'] as String?,
  formattedPhoneNumber: json['formattedPhoneNumber'] as String?,
  addressComponents:
      (json['addressComponents'] as List<dynamic>?)
          ?.map((e) => AddressComponent.fromJson(e as Map<String, dynamic>))
          .toList(),
  url: json['url'] as String?,
  adrAddress: json['adrAddress'] as String?,
);

Map<String, dynamic> _$ResultToJson(Result instance) => <String, dynamic>{
  'businessStatus': instance.businessStatus,
  'geometry': instance.geometry,
  'icon': instance.icon,
  'iconBackgroundColor': instance.iconBackgroundColor,
  'iconMaskBaseUri': instance.iconMaskBaseUri,
  'name': instance.name,
  'openingHours': instance.openingHours,
  'photos': instance.photos,
  'placeId': instance.placeId,
  'plusCode': instance.plusCode,
  'rating': instance.rating,
  'reference': instance.reference,
  'scope': instance.scope,
  'types': instance.types,
  'vicinity': instance.vicinity,
  'formattedAddress': instance.formattedAddress,
  'formattedPhoneNumber': instance.formattedPhoneNumber,
  'addressComponents': instance.addressComponents,
  'url': instance.url,
  'adrAddress': instance.adrAddress,
};
