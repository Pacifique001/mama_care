// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Photo _$PhotoFromJson(Map<String, dynamic> json) => Photo(
  height: (json['height'] as num).toInt(),
  photoReference: json['photoReference'] as String,
  width: (json['width'] as num).toInt(),
);

Map<String, dynamic> _$PhotoToJson(Photo instance) => <String, dynamic>{
  'height': instance.height,
  'photoReference': instance.photoReference,
  'width': instance.width,
};
