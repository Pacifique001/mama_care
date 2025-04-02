class VideoModel {
  final String id;
  final String title;
  final String description;
  final String url;
  final String thumbnailUrl;
  final bool isFavorite;
  final String category;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.thumbnailUrl,
    required this.isFavorite,
    required this.category,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      url: json['url'],
      thumbnailUrl: json['thumbnailUrl'],
      isFavorite: json['isFavorite'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'isFavorite': isFavorite,
      'category': category,
    };
  }

  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? url,
    String? thumbnailUrl,
    bool? isFavorite,
    String? category,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
    );
  }
}