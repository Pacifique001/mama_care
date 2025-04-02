class FoodModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<String> benefits;
  final bool isFavorite;

  FoodModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.benefits = const [],
    this.isFavorite = false,
  });

  FoodModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? benefits,
    bool? isFavorite,
  }) {
    return FoodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      benefits: benefits ?? this.benefits,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}