import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class ChatKitVideoPlayer extends StatefulWidget {
  const ChatKitVideoPlayer({
    super.key,
    required this.url,
    this.aspectRatio,
    this.autoplay = false,
  });

  final String url;
  final double? aspectRatio;
  final bool autoplay;

  @override
  State<ChatKitVideoPlayer> createState() => _ChatKitVideoPlayerState();
}

class _ChatKitVideoPlayerState extends State<ChatKitVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize = _controller.initialize().then((_) {
      if (widget.autoplay) {
        _controller.play();
        _isPlaying = true;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) {
      return;
    }
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialize,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final aspect = widget.aspectRatio ?? _controller.value.aspectRatio;
        return AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              _VideoControlsOverlay(
                isPlaying: _isPlaying,
                onToggle: _togglePlay,
              ),
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoControlsOverlay extends StatelessWidget {
  const _VideoControlsOverlay({
    required this.isPlaying,
    required this.onToggle,
  });

  final bool isPlaying;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black38,
        child: InkWell(
          onTap: onToggle,
          child: Center(
            child: Icon(
              isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatKitAudioPlayer extends StatefulWidget {
  const ChatKitAudioPlayer({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<ChatKitAudioPlayer> createState() => _ChatKitAudioPlayerState();
}

class _ChatKitAudioPlayerState extends State<ChatKitAudioPlayer> {
  late final AudioPlayer _player;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.setUrl(widget.url);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _loading
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            )
          : Row(
              children: [
                IconButton(
                  icon: Icon(
                    _player.playing ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: _togglePlay,
                ),
                Expanded(
                  child: StreamBuilder<Duration?>(
                    stream: _player.durationStream,
                    builder: (context, snapshot) {
                      final total = snapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          final value = total.inMilliseconds == 0
                              ? 0.0
                              : position.inMilliseconds / total.inMilliseconds;
                          return Slider(
                            value: value.clamp(0.0, 1.0),
                            onChanged: (newValue) {
                              final target = Duration(
                                  milliseconds:
                                      (total.inMilliseconds * newValue)
                                          .round());
                              _player.seek(target);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
