import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:flutter/material.dart';

class MediaHelper {
  static const List<String> mediaCategories = [
    "All",
    "Videos",
    "Photos",
    "Audio",
    "Documents",
    "Others"
  ];

  static IconData getMediaIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.video_library_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'audio':
        return Icons.music_note_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'archive':
        return Icons.folder_zip_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'ebook':
        return Icons.menu_book_rounded;
      case 'font':
        return Icons.text_fields_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color getMediaColor(String type) => LiquidColors.getMediaColor(type);

  static String getFileTypeLabel(String path) {
    final ext = path.split('.').last.toLowerCase();

    if ([
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'm4v', 'mpg', 'mpeg', '3gp',
      'webm', 'ts', 'mts', 'm2ts'
    ].contains(ext)) {
      return 'Video';
    }

    else if ([
      'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'aiff', 'alac', 'opus',
      'mid', 'midi', 'amr', 'ape', 'ra', 'rm', 'mka', 'm4b', 'm4p', 'ac3', 'dts'
    ].contains(ext)) {
      return 'Audio';
    }

    else if ([
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'svg', 'ico',
      'heic', 'heif', 'raw', 'cr2', 'nef', 'arw', 'dng'
    ].contains(ext)) {
      return 'Image';
    }

    else if ([
      'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'ppt', 'pptx', 'xls', 'xlsx',
      'csv', 'md', 'markdown', 'html', 'htm', 'epub', 'mobi', 'azw3', 'tex',
      'latex', 'xml', 'json', 'yaml', 'yml'
    ].contains(ext)) {
      return 'Document';
    }

    else if ([
      'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso', 'dmg', 'pkg',
      'deb', 'rpm', 'cab'
    ].contains(ext)) {
      return 'Archive';
    }

    else if (['exe', 'msi', 'apk', 'dmg', 'app', 'bat', 'sh', 'bash'].contains(ext)) {
      return 'Executable';
    }

    else if ([
      'dart', 'java', 'cpp', 'c', 'h', 'py', 'js', 'ts', 'php', 'rb', 'go',
      'rs', 'swift', 'kt', 'cs'
    ].contains(ext)) {
      return 'Code';
    } else {
      return 'File';
    }
  }

  static String formatDate(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 7) {
        return '${date.month}/${date.day}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }
}
