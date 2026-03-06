class ExerciseCatalogItem {
  final int id;
  final String name;
  final String description;
  final String muscleGroup;
  final String equipment;
  final String category;
  final String? notes;
  final String? videoLink;

  const ExerciseCatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.muscleGroup,
    required this.equipment,
    required this.category,
    this.notes,
    this.videoLink,
  });

  factory ExerciseCatalogItem.fromJson(Map<String, dynamic> json) {
    return ExerciseCatalogItem(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      muscleGroup: json['muscleGroup']?.toString() ?? json['muscle_group']?.toString() ?? '',
      equipment: json['equipment']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      notes: json['notes']?.toString(),
      videoLink: json['videoLink']?.toString() ?? json['video_link']?.toString(),
    );
  }
}
