import 'dart:convert';

class DownloadItem {
  final String id;
  final String fileName;
  final String fileSize;
  final String status;
  final String date;
  final String videoPath;
  final String downloadUrl;
  final double progress;

  DownloadItem({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.date,
    required this.videoPath,
    required this.downloadUrl,
    this.progress = 0.0,
  });
}

class VideoItem {
  final String id;
   String title;
   String path;
  final String type;
  bool isLocked;
  final String category;
  bool isDeleted;
  DateTime? deletedDate;

  VideoItem({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    this.isLocked = false,
    required this.category,
    this.isDeleted = false,
    this.deletedDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'type': type,
      'isLocked': isLocked,
      'category': category,
      'isDeleted': isDeleted,
      'deletedDate': deletedDate?.toIso8601String(),
    };
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? 'video',
      isLocked: json['isLocked'] ?? false,
      category: json['category'] ?? 'Videos',
      isDeleted: json['isDeleted'] ?? false,
      deletedDate: json['deletedDate'] != null
          ? DateTime.tryParse(json['deletedDate'])
          : null,
    );
  }

  VideoItem copyWith({
    String? id,
    String? title,
    String? path,
    String? type,
    bool? isLocked,
    String? category,
    bool? isDeleted,
    DateTime? deletedDate,
  }) {
    return VideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      type: type ?? this.type,
      isLocked: isLocked ?? this.isLocked,
      category: category ?? this.category,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedDate: deletedDate ?? this.deletedDate,
    );
  }

  String toStorageString() {
    return '$id|$title|$path|$type|$isLocked|$category|$isDeleted|${deletedDate?.toIso8601String() ?? ""}';
  }

  factory VideoItem.fromStorageString(String storageString) {
    final parts = storageString.split('|');

    if (parts.length < 6) {

      return VideoItem(
        id: parts[0],
        title: parts[1],
        path: parts[2],
        type: parts[3],
        isLocked: parts[4] == 'true',
        category: parts[5],
        isDeleted: false,
        deletedDate: null,
      );
    }

    return VideoItem(
      id: parts[0],
      title: parts[1],
      path: parts[2],
      type: parts[3],
      isLocked: parts[4] == 'true',
      category: parts[5],
      isDeleted: parts.length > 6 ? parts[6] == 'true' : false,
      deletedDate: parts.length > 7 && parts[7].isNotEmpty
          ? DateTime.tryParse(parts[7])
          : null,
    );
  }
}
