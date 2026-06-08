
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
  final bool encrypted;
  bool isHidden;
  bool isFavorite;

  VideoItem({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    this.isLocked = false,
    required this.category,
    this.isDeleted = false,
    this.deletedDate,
    this.encrypted = false,
    this.isHidden = false,
    this.isFavorite = false,
  });

  VideoItem copyWith({
    String? id,
    String? title,
    String? path,
    String? type,
    bool? isLocked,
    String? category,
    bool? isDeleted,
    DateTime? deletedDate,
    bool? encrypted,
    bool? isHidden,
    bool? isFavorite,
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
      encrypted: encrypted ?? this.encrypted,
      isHidden: isHidden ?? this.isHidden,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  static String _safe(String v) =>
      v.replaceAll('|', ' ').replaceAll(RegExp(r'[\r\n]'), ' ');

  String toStorageString() {
    return '$id|${_safe(title)}|${_safe(path)}|$type|$isLocked|${_safe(category)}|$isDeleted|${deletedDate?.toIso8601String() ?? ""}|$encrypted|$isHidden|$isFavorite';
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
      encrypted: parts.length > 8 ? parts[8] == 'true' : false,
      isHidden: parts.length > 9 ? parts[9] == 'true' : false,
      isFavorite: parts.length > 10 ? parts[10] == 'true' : false,
    );
  }
}
