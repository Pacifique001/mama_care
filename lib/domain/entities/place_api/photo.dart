import 'package:json_annotation/json_annotation.dart';

part 'photo.g.dart';

@JsonSerializable()
class Photo {
  final int height;
  final String photoReference;
  final int width;

  Photo({
    required this.height,
    required this.photoReference,
    required this.width,
  });

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  Map<String, dynamic> toJson() => _$PhotoToJson(this);
}