import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class SharedPrefsService {
  static final SharedPrefsService _instance = SharedPrefsService._internal();
  factory SharedPrefsService() => _instance;
  SharedPrefsService._internal();

  static const String _videosKey = 'user_videos';
  static const String _deletedVideosKey = 'deleted_videos_backup';
  static const String _settingsKey = 'app_settings';

  Future<void> saveVideos(List<VideoItem> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = videos.map((video) => video.toJson()).toList();
      await prefs.setString(_videosKey, json.encode(videosJson));
    } catch (e) {
    }
  }

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
      return [];
    }
  }

  Future<void> saveVideo(VideoItem video) async {
    try {
      final videos = await getVideos();

      videos.removeWhere((v) => v.id == video.id);

      videos.add(video);

      await saveVideos(videos);
    } catch (e) {
    }
  }

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

        await _backupDeletedVideo(deletedVideo);
      }
    } catch (e) {
    }
  }

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
    }
  }

  Future<List<VideoItem>> getDeletedVideos() async {
    try {
      final videos = await getVideos();
      return videos.where((video) => video.isDeleted).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<VideoItem>> getActiveVideos() async {
    try {
      final videos = await getVideos();
      return videos.where((video) => !video.isDeleted).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> permanentDelete(String videoId) async {
    try {
      final videos = await getVideos();
      videos.removeWhere((v) => v.id == videoId);
      await saveVideos(videos);
    } catch (e) {
    }
  }

  Future<void> clearAllDeleted() async {
    try {
      final videos = await getVideos();
      final activeVideos = videos.where((v) => !v.isDeleted).toList();
      await saveVideos(activeVideos);
    } catch (e) {
    }
  }

  Future<void> _backupDeletedVideo(VideoItem video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString(_deletedVideosKey) ?? '[]';
      final List<dynamic> backupList = json.decode(backupJson);

      backupList.add(video.toJson());
      await prefs.setString(_deletedVideosKey, json.encode(backupList));
    } catch (e) {
    }
  }

  Future<VideoItem?> getVideoById(String videoId) async {
    try {
      final videos = await getVideos();
      return videos.firstWhere((v) => v.id == videoId);
    } catch (e) {
      return null;
    }
  }

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
      return {};
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(settings));
    } catch (e) {
    }
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
    }
  }

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
        if (kDebugMode) {
        }
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  Future<Map<String, int>> getStatistics() async {
    try {
      final videos = await getVideos();
      final deletedVideos = videos.where((v) => v.isDeleted).toList();
      final lockedVideos = videos.where((v) => v.isLocked).toList();

      return {
        'total': videos.length,
        'database': deletedVideos.length,
        'active': videos.length - deletedVideos.length,
        'locked': lockedVideos.length,
        'local': videos.where((v) => v.type == 'local').length,
        'cloud': videos.where((v) => v.type == 'cloud').length,
      };
    } catch (e) {
      return {};
    }
  }
}
