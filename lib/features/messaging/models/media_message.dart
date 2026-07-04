class MediaMessage {
  final String id;
  final String mediaUrl;
  final String? mediaType; // 'image', 'video'
  final int? fileSizeBytes;
  final String? thumbnailUrl;
  final DateTime createdAt;

  MediaMessage({
    required this.id,
    required this.mediaUrl,
    this.mediaType,
    this.fileSizeBytes,
    this.thumbnailUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'fileSizeBytes': fileSizeBytes,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MediaMessage.fromMap(Map<String, dynamic> map) => MediaMessage(
        id: map['id'] as String,
        mediaUrl: map['mediaUrl'] as String,
        mediaType: map['mediaType'] as String?,
        fileSizeBytes: map['fileSizeBytes'] as int?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
