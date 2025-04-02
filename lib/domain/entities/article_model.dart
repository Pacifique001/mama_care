class ArticleModel {
  final String id;
  final String title;
  final String detail;
  final String image;
  final String author;
  final String imageUrl;
  final DateTime publishDate;
  final bool isBookmarked;
  final List<String> tags;

  ArticleModel({
    required this.id,
    required this.title,
    required this.detail,
    required this.image,
    required this.author,
    required this.imageUrl,
    required this.publishDate,
    this.isBookmarked = false,
    this.tags = const [],
  });

  ArticleModel copyWith({
    String? id,
    String? title,
    String? detail,
    String? image,
    String? author,
    String? imageUrl,
    DateTime? publishDate,
    bool? isBookmarked,
    List<String>? tags,
  }) {
    return ArticleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      image: image ?? this.image,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      publishDate: publishDate ?? this.publishDate,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      tags: tags ?? this.tags,
    );
  }

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id'],
      title: json['title'],
      detail: json['detail'],
      image: json['image'],
      author: json['author'],
      imageUrl: json['imageUrl'],
      publishDate: DateTime.parse(json['publishDate']),
      isBookmarked: json['isBookmarked'] ?? false,
      tags: List<String>.from(json['tags']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'detail': detail,
      'image': image,
      'author': author,
      'imageUrl': imageUrl,
      'publishDate': publishDate.toIso8601String(),
      'isBookmarked': isBookmarked,
      'tags': tags,
    };
  }
}