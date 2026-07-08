
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
  // Whether this item is currently saved/visible in the device gallery.
  // Videos default to "hidden from gallery" (locked); unlocking saves them
  // back to the gallery. `galleryId` is the device asset id, kept so the item
  // can be removed from the gallery again when re-hidden.
  bool inGallery;
  String galleryId;
  // Where this file came from, so unlocking can restore it to its original
  // spot. `origin` is 'gallery' | 'camera' | 'file' | ''. `originAlbum` is the
  // device album relative path to restore into (e.g. 'DCIM/Camera',
  // 'Pictures/Trips'); empty means "no known original location".
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
    return '$id|${_safe(title)}|${_safe(path)}|$type|$isLocked|${_safe(category)}|$isDeleted|${deletedDate?.toIso8601String() ?? ""}|$encrypted|$isHidden|$isFavorite|$inGallery|${_safe(galleryId)}|${_safe(origin)}|${_safe(originAlbum)}';
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
      inGallery: parts.length > 11 ? parts[11] == 'true' : false,
      galleryId: parts.length > 12 ? parts[12] : '',
      origin: parts.length > 13 ? parts[13] : '',
      originAlbum: parts.length > 14 ? parts[14] : '',
    );
  }
}
