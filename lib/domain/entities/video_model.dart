import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // For @immutable

@immutable // Mark as immutable
class VideoModel extends Equatable { // Extend Equatable
  final String id;
  final String title;
  final String description;
  final String url;
  final String thumbnailUrl;
  // isFavorite status is now managed per user in user_video_prefs table,
  // so it shouldn't be part of the core VideoModel unless it represents
  // a global 'featured' status or similar.
  // Assuming 'isFavorite' here might represent something else or is a remnant.
  // If it truly represents the *user's* favorite status, it shouldn't be stored
  // directly in the main 'app_videos' table/model.
  // For this example, I'll keep it but comment on its potential issue.
  final bool isFavorite; // <-- Reconsider if this belongs here vs user_video_prefs
  final String category;
  final int? publishedAt; // Optional: Store publish timestamp (MillisecondsSinceEpoch)
  final int? duration; // Optional: Store duration in seconds

  // Use a const constructor for immutable class
  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.thumbnailUrl,
    this.isFavorite = false, // Default to false if kept
    required this.category,
    this.publishedAt, // Optional
    this.duration, // Optional
  });

  // Factory constructor for creating from JSON/Map (e.g., from API or DB)
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      // Use null-aware operators and defaults for safety
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'No Title',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      // Convert integer from DB back to boolean
      isFavorite: (json['isFavorite'] as int? ?? 0) == 1, // <-- Convert Int to Bool
      category: json['category'] as String? ?? 'Uncategorized',
      publishedAt: json['publishedAt'] as int?,
      duration: json['duration'] as int?,
    );
  }

  // Alias for consistency if needed elsewhere
  factory VideoModel.fromMap(Map<String, dynamic> map) => VideoModel.fromJson(map);

  // Method to convert instance to a Map suitable for DB or API JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      // Convert boolean to integer (0 or 1) for DB storage
      'isFavorite': isFavorite ? 1 : 0, // <-- Convert Bool to Int
      'category': category,
      'publishedAt': publishedAt,
      'duration': duration,
    };
  }

   // Alias for consistency if needed elsewhere
   Map<String, dynamic> toMap() => toJson();


  // copyWith method for creating modified copies (useful for state updates)
  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? url,
    String? thumbnailUrl,
    bool? isFavorite,
    String? category,
    int? publishedAt,
    ValueGetter<int?>? nullablePublishedAt, // Allow setting to null
    int? duration,
     ValueGetter<int?>? nullableDuration, // Allow setting to null
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      publishedAt: nullablePublishedAt != null ? nullablePublishedAt() : (publishedAt ?? this.publishedAt),
      duration: nullableDuration != null ? nullableDuration() : (duration ?? this.duration),
    );
  }

  // --- Equatable Implementation ---
  @override
  List<Object?> get props => [
        id,
        title,
        description,
        url,
        thumbnailUrl,
        isFavorite,
        category,
        publishedAt,
        duration,
      ];

  // Optional: Improve toString for debugging (provided by Equatable if stringify=true)
  @override
  bool get stringify => true;
}