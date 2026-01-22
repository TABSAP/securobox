// services/shared_prefs_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class SharedPrefsService {
  static final SharedPrefsService _instance = SharedPrefsService._internal();
  factory SharedPrefsService() => _instance;
  SharedPrefsService._internal();

  static const String _videosKey = 'user_videos';
  static const String _deletedVideosKey = 'deleted_videos_backup';
  static const String _settingsKey = 'app_settings';

  // Save all videos
  Future<void> saveVideos(List<VideoItem> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = videos.map((video) => video.toJson()).toList();
      await prefs.setString(_videosKey, json.encode(videosJson));
    } catch (e) {
      print('Error saving videos: $e');
    }
  }

  // Get all videos
  Future<List<VideoItem>> getVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getString(_videosKey);

      if (videosJson == null || videosJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = json.decode(videosJson);
      return decoded.map((item) => VideoItem.fromJson(item)).toList();
    } catch (e) {
      print('Error getting videos: $e');
      return [];
    }
  }

  // Add or update a single video
  Future<void> saveVideo(VideoItem video) async {
    try {
      final videos = await getVideos();

      // Remove existing video with same id
      videos.removeWhere((v) => v.id == video.id);

      // Add new/updated video
      videos.add(video);

      await saveVideos(videos);
    } catch (e) {
      print('Error saving video: $e');
    }
  }

  // Delete video (soft delete)
  Future<void> softDeleteVideo(String videoId) async {
    try {
      final videos = await getVideos();
      final index = videos.indexWhere((v) => v.id == videoId);

      if (index != -1) {
        final deletedVideo = videos[index].copyWith(
          isDeleted: true,
          deletedDate: DateTime.now(),
        );

        videos[index] = deletedVideo;
        await saveVideos(videos);

        // Also backup deleted video
        await _backupDeletedVideo(deletedVideo);
      }
    } catch (e) {
      print('Error soft deleting video: $e');
    }
  }

  // Restore video
  Future<void> restoreVideo(String videoId) async {
    try {
      final videos = await getVideos();
      final index = videos.indexWhere((v) => v.id == videoId);

      if (index != -1) {
        final restoredVideo = videos[index].copyWith(
          isDeleted: false,
          deletedDate: null,
        );

        videos[index] = restoredVideo;
        await saveVideos(videos);
      }
    } catch (e) {
      print('Error restoring video: $e');
    }
  }

  // Get deleted videos only
  Future<List<VideoItem>> getDeletedVideos() async {
    try {
      final videos = await getVideos();
      return videos.where((video) => video.isDeleted).toList();
    } catch (e) {
      print('Error getting deleted videos: $e');
      return [];
    }
  }

  // Get active (not deleted) videos
  Future<List<VideoItem>> getActiveVideos() async {
    try {
      final videos = await getVideos();
      return videos.where((video) => !video.isDeleted).toList();
    } catch (e) {
      print('Error getting active videos: $e');
      return [];
    }
  }

  // Permanently delete video
  Future<void> permanentDelete(String videoId) async {
    try {
      final videos = await getVideos();
      videos.removeWhere((v) => v.id == videoId);
      await saveVideos(videos);
    } catch (e) {
      print('Error permanently deleting video: $e');
    }
  }

  // Clear all deleted videos
  Future<void> clearAllDeleted() async {
    try {
      final videos = await getVideos();
      final activeVideos = videos.where((v) => !v.isDeleted).toList();
      await saveVideos(activeVideos);
    } catch (e) {
      print('Error clearing deleted videos: $e');
    }
  }

  // Backup deleted video (optional - for recovery)
  Future<void> _backupDeletedVideo(VideoItem video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString(_deletedVideosKey) ?? '[]';
      final List<dynamic> backupList = json.decode(backupJson);

      backupList.add(video.toJson());
      await prefs.setString(_deletedVideosKey, json.encode(backupList));
    } catch (e) {
      print('Error backing up deleted video: $e');
    }
  }

  // Get video by ID
  Future<VideoItem?> getVideoById(String videoId) async {
    try {
      final videos = await getVideos();
      return videos.firstWhere((v) => v.id == videoId);
    } catch (e) {
      print('Error getting video by ID: $e');
      return null;
    }
  }

  // Get app settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson == null) {
        return {
          'autoPlay': true,
          'videoQuality': '720p',
          'enableNotifications': true,
          'theme': 'light',
          'keepScreenOn': false,
        };
      }

      return Map<String, dynamic>.from(json.decode(settingsJson));
    } catch (e) {
      print('Error getting settings: $e');
      return {};
    }
  }

  // Save app settings
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(settings));
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  // Clear all data (for testing/logout)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing data: $e');
    }
  }

  // Initialize with sample data (for testing)
  Future<void> initializeWithSampleData() async {
    try {
      final videos = await getVideos();

      if (videos.isEmpty) {
        final sampleVideos = [
          VideoItem(
            id: '1',
            title: 'Nature Documentary',
            path: '/videos/nature.mp4',
            type: 'local',
            isLocked: false,
            category: 'Educational',
            isDeleted: true,
            deletedDate: DateTime.now().subtract(Duration(days: 2)),
          ),
          VideoItem(
            id: '2',
            title: 'Favorite Music Video',
            path: '/videos/music.mp4',
            type: 'cloud',
            isLocked: true,
            category: 'Music',
            isDeleted: true,
            deletedDate: DateTime.now().subtract(Duration(days: 1)),
          ),
          VideoItem(
            id: '3',
            title: 'Home Video',
            path: '/videos/home.mp4',
            type: 'local',
            isLocked: false,
            category: 'Personal',
            isDeleted: false,
          ),
          VideoItem(
            id: '4',
            title: 'Action Movie',
            path: '/videos/movie.mp4',
            type: 'local',
            isLocked: false,
            category: 'Movies',
            isDeleted: true,
            deletedDate: DateTime.now(),
          ),
        ];

        await saveVideos(sampleVideos);
        print('Sample data initialized with ${sampleVideos.length} videos');
      }
    } catch (e) {
      print('Error initializing sample data: $e');
    }
  }

  // Get statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      final videos = await getVideos();
      final deletedVideos = videos.where((v) => v.isDeleted).toList();
      final lockedVideos = videos.where((v) => v.isLocked).toList();

      return {
        'total': videos.length,
        'deleted': deletedVideos.length,
        'active': videos.length - deletedVideos.length,
        'locked': lockedVideos.length,
        'local': videos.where((v) => v.type == 'local').length,
        'cloud': videos.where((v) => v.type == 'cloud').length,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {};
    }
  }
}