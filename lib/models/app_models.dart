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
  final int? encryptionVersion;
  bool isHidden;
  bool isFavorite;
  bool inGallery;
  String galleryId;
  String origin;
  String originAlbum;

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
    this.encryptionVersion,
    this.isHidden = false,
    this.isFavorite = false,
    this.inGallery = false,
    this.galleryId = '',
    this.origin = '',
    this.originAlbum = '',
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
    int? encryptionVersion,
    bool? isHidden,
    bool? isFavorite,
    bool? inGallery,
    String? galleryId,
    String? origin,
    String? originAlbum,
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
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      isHidden: isHidden ?? this.isHidden,
      isFavorite: isFavorite ?? this.isFavorite,
      inGallery: inGallery ?? this.inGallery,
      galleryId: galleryId ?? this.galleryId,
      origin: origin ?? this.origin,
      originAlbum: originAlbum ?? this.originAlbum,
    );
  }

  static String _safe(String v) =>
      v.replaceAll('|', ' ').replaceAll(RegExp(r'[\r\n]'), ' ');

  String toStorageString() {
    return '$id|${_safe(title)}|${_safe(path)}|$type|$isLocked|${_safe(category)}|$isDeleted|${deletedDate?.toIso8601String() ?? ""}|$encrypted|$isHidden|$isFavorite|$inGallery|${_safe(galleryId)}|${_safe(origin)}|${_safe(originAlbum)}|${encryptionVersion ?? ""}';
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
      encryptionVersion: parts.length > 15 ? int.tryParse(parts[15]) : null,
      isHidden: parts.length > 9 ? parts[9] == 'true' : false,
      isFavorite: parts.length > 10 ? parts[10] == 'true' : false,
      inGallery: parts.length > 11 ? parts[11] == 'true' : false,
      galleryId: parts.length > 12 ? parts[12] : '',
      origin: parts.length > 13 ? parts[13] : '',
      originAlbum: parts.length > 14 ? parts[14] : '',
    );
  }
}
