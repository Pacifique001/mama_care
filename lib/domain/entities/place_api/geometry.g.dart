// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geometry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Geometry _$GeometryFromJson(Map<String, dynamic> json) => Geometry(
  location: Location.fromJson(json['location'] as Map<String, dynamic>),
  viewport: Viewport.fromJson(json['viewport'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GeometryToJson(Geometry instance) => <String, dynamic>{
  'location': instance.location,
  'viewport': instance.viewport,
};
