import 'package:json_annotation/json_annotation.dart';
import 'package:mama_care/domain/entities/place_api/viewport.dart';
import 'package:mama_care/domain/entities/place_api/location.dart';

part 'geometry.g.dart';

@JsonSerializable()
class Geometry {
  final Location location;
  final Viewport viewport;

  Geometry({
    required this.location,
    required this.viewport,
  });

  factory Geometry.fromJson(Map<String, dynamic> json) =>
      _$GeometryFromJson(json);

  Map<String, dynamic> toJson() => _$GeometryToJson(this);
}