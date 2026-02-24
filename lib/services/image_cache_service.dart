import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageCacheService {
  static ImageCacheService? _instance;
  static ImageCacheService get instance => _instance ??= ImageCacheService._();
  
  ImageCacheService._();
  
  String? _cacheDir;
  final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50;

  Future<String> get cacheDirectory async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getApplicationCacheDirectory();
    _cacheDir = '${dir.path}/exercise_images';
    await Directory(_cacheDir!).create(recursive: true);
    return _cacheDir!;
  }

  String _getFileName(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.last;
  }

  Future<Uint8List?> getImage(String url) async {
    final fileName = _getFileName(url);
    
    // 1. Sprawdź pamięć
    if (_memoryCache.containsKey(fileName)) {
      return _memoryCache[fileName];
    }
    
    // 2. Sprawdź dysk
    try {
      final cacheDir = await cacheDirectory;
      final file = File('$cacheDir/$fileName');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _addToMemoryCache(fileName, bytes);
        return bytes;
      }
    } catch (e) {
      debugPrint('Błąd odczytu cache: $e');
    }
    
    // 3. Pobierz z sieci
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        _addToMemoryCache(fileName, bytes);
        _saveToFile(fileName, bytes);
        return bytes;
      }
    } catch (e) {
      debugPrint('Błąd pobierania obrazu: $e');
    }
    
    return null;
  }

  void _addToMemoryCache(String key, Uint8List bytes) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = bytes;
  }

  Future<void> _saveToFile(String fileName, Uint8List bytes) async {
    try {
      final cacheDir = await cacheDirectory;
      final file = File('$cacheDir/$fileName');
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Błąd zapisu cache: $e');
    }
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final cacheDir = await cacheDirectory;
      final dir = Directory(cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
    } catch (e) {
      debugPrint('Błąd czyszczenia cache: $e');
    }
  }

  Future<int> getCacheSize() async {
    try {
      final cacheDir = await cacheDirectory;
      final dir = Directory(cacheDir);
      if (!await dir.exists()) return 0;
      
      int size = 0;
      await for (final file in dir.list()) {
        if (file is File) {
          size += await file.length();
        }
      }
      return size;
    } catch (e) {
      return 0;
    }
  }
}
