import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/workout_service.dart';

class ExerciseMediaView extends StatefulWidget {
  const ExerciseMediaView({
    super.key,
    this.url,
    this.mediaType,
    this.name,
  });

  final String? url;
  final String? mediaType;
  final String? name;

  @override
  State<ExerciseMediaView> createState() => _ExerciseMediaViewState();
}

class _ExerciseMediaViewState extends State<ExerciseMediaView> {
  VideoPlayerController? _controller;
  bool _videoFailed = false;

  String get _src => resolveMediaUrl(widget.url);

  String? get _kind {
    if (_src.isEmpty || (widget.mediaType ?? '').toUpperCase() == 'NONE') {
      return null;
    }
    final type = (widget.mediaType ?? '').toUpperCase();
    if (type == 'IMAGE' || type == 'VIDEO') return type;
    final lower = _src.toLowerCase().split('?').first;
    if (RegExp(r'\.(png|jpe?g|gif|webp|bmp|avif)$').hasMatch(lower)) {
      return 'IMAGE';
    }
    if (RegExp(r'\.(mp4|webm|ogg|mov|m4v)$').hasMatch(lower)) {
      return 'VIDEO';
    }
    return 'VIDEO';
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant ExerciseMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.mediaType != widget.mediaType) {
      _disposeVideo();
      _videoFailed = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    if (_kind != 'VIDEO' || _src.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(_src));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoFailed = true);
    }
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _openLightbox(String src) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(src, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    if (kind == null) return const SizedBox.shrink();

    if (kind == 'IMAGE') {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InkWell(
          onTap: () => _openLightbox(_src),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.network(
                  _src,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Não foi possível carregar a foto')),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Ampliar foto', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videoFailed) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Não foi possível carregar o vídeo', style: TextStyle(color: Colors.white54)),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              Material(
                color: Colors.black38,
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 40,
                  color: Colors.white,
                  onPressed: () {
                    setState(() {
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    });
                  },
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
