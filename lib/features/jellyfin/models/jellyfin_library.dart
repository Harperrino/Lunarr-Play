/// A Jellyfin user view (library folder) as returned by `/Users/{id}/Views`.
class JellyfinLibrary {
  const JellyfinLibrary({
    required this.id,
    required this.name,
    this.collectionType = '',
    this.imageTag,
  });

  final String id;
  final String name;

  /// `movies`, `tvshows` or `mixed`; empty when unknown.
  final String collectionType;

  final String? imageTag;

  bool get isTvShows => collectionType == 'tvshows';
  bool get isMovies => collectionType == 'movies';

  factory JellyfinLibrary.fromJson(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    final imageTagsMap = imageTags is Map<String, dynamic> ? imageTags : null;

    return JellyfinLibrary(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      collectionType: json['CollectionType'] as String? ?? '',
      imageTag: imageTagsMap?['Primary'] as String?,
    );
  }
}
