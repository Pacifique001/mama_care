// lib/domain/entities/place_api/place_result.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:mama_care/utils/asset_helper.dart'; // Assuming API Key is here (move to env)
import 'geometry.dart';
import 'opening_hours.dart';
import 'photo.dart';
import 'location.dart';

part 'place_result.g.dart';

@JsonSerializable(explicitToJson: true)
class PlaceResult extends Equatable {
  @JsonKey(name: 'place_id')
  final String placeId;

  @JsonKey(name: 'geometry')
  final Geometry? geometry;

  @JsonKey(name: 'name')
  final String? name;

  @JsonKey(name: 'vicinity')
  final String? vicinity;

  @JsonKey(name: 'opening_hours')
  final OpeningHours? openingHours;

  @JsonKey(name: 'rating')
  final double? rating;

  @JsonKey(name: 'user_ratings_total')
  final int? userRatingsTotal;

  @JsonKey(name: 'photos')
  final List<Photo>? photos;

  @JsonKey(name: 'types')
  final List<String>? types;

  // ADDED: Field for phone number (often comes as formatted_phone_number)
  @JsonKey(name: 'formatted_phone_number')
  final String? formattedPhoneNumber; // Use this field name

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isFavorite;

  const PlaceResult({
    required this.placeId,
    this.geometry,
    this.name,
    this.vicinity,
    this.openingHours,
    this.rating,
    this.userRatingsTotal,
    this.photos,
    this.types,
    this.formattedPhoneNumber, // Add to constructor
    this.isFavorite = false,
  });

  // --- Calculated Getters ---
  bool get isOpen => openingHours?.openNow ?? false;
  Location? get location => geometry?.location;
  String get displayAddress => vicinity ?? 'Address not available';

  // ADDED: imageUrl getter
  String? get imageUrl {
    if (photos != null && photos!.isNotEmpty) {
      // Construct the URL using the first photo reference and API key
      // IMPORTANT: Move API Key retrieval to a secure method (e.g., from config/env)
      final String? apiKey =
          dotenv.env["'GOOGLE_MAPS_API_KEY'"]; // Replace with your secure key retrieval
      if (apiKey!.isEmpty || apiKey == 'YOUR_API_KEY') {
        print(
          "Warning: Google Places API Key is missing or invalid in imageUrl getter.",
        );
        return null; // Don't attempt to build URL without key
      }
      return 'https://maps.googleapis.com/maps/api/place/photo'
          '?maxwidth=400' // Example width
          '&photoreference=${photos!.first.photoReference}'
          '&key=$apiKey';
    }
    return null; // Return null if no photos are available
  }

  // ADDED: Convenience getter for phone number
  String? get phoneNumber => formattedPhoneNumber;

  factory PlaceResult.fromJson(Map<String, dynamic> json) =>
      _$PlaceResultFromJson(json);
  Map<String, dynamic> toJson() => _$PlaceResultToJson(this);

  PlaceResult copyWith({
    String? placeId,
    Geometry? geometry,
    String? name,
    String? vicinity,
    OpeningHours? openingHours,
    double? rating,
    int? userRatingsTotal,
    List<Photo>? photos,
    List<String>? types,
    String? formattedPhoneNumber, // Add phone number
    bool? isFavorite,
  }) {
    return PlaceResult(
      placeId: placeId ?? this.placeId,
      geometry: geometry ?? this.geometry,
      name: name ?? this.name,
      vicinity: vicinity ?? this.vicinity,
      openingHours: openingHours ?? this.openingHours,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      photos: photos ?? this.photos,
      types: types ?? this.types,
      formattedPhoneNumber:
          formattedPhoneNumber ?? this.formattedPhoneNumber, // Add phone number
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
    placeId, geometry, name, vicinity, openingHours, rating,
    userRatingsTotal,
    photos,
    types,
    formattedPhoneNumber,
    isFavorite, // Add phone number
  ];
}
