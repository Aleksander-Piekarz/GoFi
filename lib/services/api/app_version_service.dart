import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Informacje o dostępnej aktualizacji
class AppUpdateInfo {
  final bool needsUpdate;
  final bool needsForceUpdate;
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String? androidDownloadUrl;
  final String? iosDownloadUrl;

  const AppUpdateInfo({
    required this.needsUpdate,
    required this.needsForceUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    this.androidDownloadUrl,
    this.iosDownloadUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      needsUpdate: json['needsUpdate'] ?? false,
      needsForceUpdate: json['needsForceUpdate'] ?? false,
      latestVersion: json['latestVersion'] ?? '1.0.0',
      currentVersion: json['currentVersion'] ?? '1.0.0',
      releaseNotes: json['releaseNotes'] ?? '',
      androidDownloadUrl: json['androidDownloadUrl'],
      iosDownloadUrl: json['iosDownloadUrl'],
    );
  }

  /// Zwraca URL do pobrania dla aktualnej platformy
  String? get downloadUrl {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return androidDownloadUrl;
    if (Platform.isIOS) return iosDownloadUrl;
    return null;
  }
}

class AppVersionService {
  final ApiClient api;
  static const String currentVersion = '1.0.0';
  
  AppVersionService({required this.api});

  /// Sprawdza czy jest dostępna aktualizacja
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await api.get('/app-version/check/$currentVersion');
      
      if (response['success'] == true && response['data'] != null) {
        return AppUpdateInfo.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Błąd sprawdzania aktualizacji: $e');
      return null;
    }
  }

  /// Pobiera informacje o najnowszej wersji
  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final response = await api.get('/app-version');
      if (response['success'] == true) {
        return response['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Błąd pobierania informacji o wersji: $e');
      return null;
    }
  }
}
