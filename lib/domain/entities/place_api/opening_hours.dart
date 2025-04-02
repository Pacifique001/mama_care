import 'package:json_annotation/json_annotation.dart';

part 'opening_hours.g.dart';

@JsonSerializable()
class OpeningHours {
  final bool openNow;

  OpeningHours({
    required this.openNow,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursFromJson(json);

  Map<String, dynamic> toJson() => _$OpeningHoursToJson(this);
}