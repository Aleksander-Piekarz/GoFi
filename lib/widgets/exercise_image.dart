import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

class ExerciseImageConfig {
  static String? _baseUrl;
  
  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
  
  static String get baseUrl {
    if (_baseUrl != null) return _baseUrl!;
    
    // Ta sama logika co w providers.dart
    String url = const String.fromEnvironment('API_BASE');
    if (url.isEmpty) {
      if (kIsWeb) {
        url = 'http://91.123.188.186:3001';
      } else {
        url = 'http://91.123.188.186:3001';
      }
    } else {
      // Usuń /api z końca jeśli jest
      url = url.replaceAll('/api', '');
    }
    return url;
  }
  
  static String getImageUrl(String exerciseCode) {
    return '$baseUrl/images/exercises/$exerciseCode.gif';
  }
}

class NetworkExerciseImage extends StatefulWidget {
  final String exerciseCode;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const NetworkExerciseImage({
    super.key,
    required this.exerciseCode,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<NetworkExerciseImage> createState() => _NetworkExerciseImageState();
}

class _NetworkExerciseImageState extends State<NetworkExerciseImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  bool _useLocalAsset = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(NetworkExerciseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseCode != widget.exerciseCode) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _useLocalAsset = false;
    });

    final url = ExerciseImageConfig.getImageUrl(widget.exerciseCode);
    final bytes = await ImageCacheService.instance.getImage(url);

    if (!mounted) return;

    if (bytes != null) {
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    } else {
      // Fallback na lokalne assets
      setState(() {
        _useLocalAsset = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (_isLoading) {
      imageWidget = widget.placeholder ?? _buildPlaceholder();
    } else if (_useLocalAsset) {
      imageWidget = Image.asset(
        'assets/images/exercises/${widget.exerciseCode}.gif',
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.errorWidget ?? _buildErrorWidget(),
      );
    } else if (_imageBytes != null) {
      imageWidget = Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.errorWidget ?? _buildErrorWidget(),
      );
    } else {
      imageWidget = widget.errorWidget ?? _buildErrorWidget();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade300,
      child: const Icon(Icons.fitness_center, size: 32, color: Colors.grey),
    );
  }
}

class ExerciseImage extends StatelessWidget {
  final String exerciseCode;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ExerciseImage({
    super.key,
    required this.exerciseCode,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return NetworkExerciseImage(
      exerciseCode: exerciseCode,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }
}
