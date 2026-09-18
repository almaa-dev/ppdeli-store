import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:video_player/video_player.dart';

class CustomVideoPlayerPage extends StatelessWidget {
  final String filePath;
  final bool autoPlay;
  final bool isNetwork;
  final String? title;

  const CustomVideoPlayerPage({
    super.key,
    required this.filePath,
    this.autoPlay = true,
    this.isNetwork = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: title != null && title!.trim().isNotEmpty
            ? Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: robotoMedium.copyWith(
                  color: Colors.white,
                  fontSize: Dimensions.fontSizeDefault,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomVideoPlayerWidget(
                filePath: filePath,
                autoPlay: autoPlay,
                isNetwork: isNetwork,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                backgroundColor: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomVideoPlayerWidget extends StatefulWidget {
  final String filePath;
  final bool autoPlay;
  final bool isNetwork;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const CustomVideoPlayerWidget({
    super.key,
    required this.filePath,
    this.autoPlay = true,
    this.isNetwork = false,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  State<CustomVideoPlayerWidget> createState() =>
      _CustomVideoPlayerWidgetState();
}

class _CustomVideoPlayerWidgetState extends State<CustomVideoPlayerWidget> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeVideo;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();

    _controller = widget.isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(widget.filePath))
        : VideoPlayerController.file(File(widget.filePath));
    _initializeVideo = _controller
        .initialize()
        .then((_) async {
          await _controller.setLooping(false);
          if (widget.autoPlay) {
            await _controller.play();
          }
          if (mounted) {
            setState(() {});
          }
        })
        .catchError((Object error) {
          _initializationError = error;
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

  bool _isVideoCompleted(VideoPlayerValue value) {
    if (!value.isInitialized || value.duration == Duration.zero) {
      return false;
    }

    return !value.isPlaying &&
        value.position >= (value.duration - const Duration(milliseconds: 200));
  }

  String _formatDuration(Duration duration) {
    final int totalSeconds = duration.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }

    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _playbackLabel(VideoPlayerValue value) {
    if (_isVideoCompleted(value)) {
      return 'Completed';
    }
    if (value.isPlaying) {
      return 'Playing';
    }
    return 'Paused';
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    final VideoPlayerValue value = _controller.value;
    if (_isVideoCompleted(value)) {
      await _controller.seekTo(Duration.zero);
      await _controller.play();
    } else if (value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius borderRadius =
        widget.borderRadius ?? BorderRadius.circular(Dimensions.radiusSmall);

    return FutureBuilder<void>(
      future: _initializeVideo,
      builder: (context, snapshot) {
        if (_initializationError != null || snapshot.hasError) {
          return _VideoPlayerStatusView(
            borderRadius: borderRadius,
            backgroundColor: widget.backgroundColor ?? Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  'Unable to play video',
                  style: robotoMedium.copyWith(
                    color: Colors.white,
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !_controller.value.isInitialized) {
          return _VideoPlayerStatusView(
            borderRadius: borderRadius,
            backgroundColor: widget.backgroundColor ?? Colors.black,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          );
        }

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, videoValue, _) {
            final bool isCompleted = _isVideoCompleted(videoValue);
            final bool showActionButton = !videoValue.isPlaying;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _togglePlayback,
                  child: AspectRatio(
                    aspectRatio: videoValue.aspectRatio == 0
                        ? 16 / 9
                        : videoValue.aspectRatio,
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              isAntiAlias: false,
                              color: widget.backgroundColor ?? Colors.black,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                          if (showActionButton)
                            Material(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _togglePlayback,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    Dimensions.paddingSizeDefault,
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.replay_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 34,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                    colors: VideoProgressColors(
                      playedColor: theme.primaryColor,
                      bufferedColor: Colors.white.withValues(alpha: 0.35),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeSmall,
                        vertical: Dimensions.paddingSizeExtraSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                      child: Text(
                        _playbackLabel(videoValue),
                        style: robotoMedium.copyWith(
                          color: Colors.white,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatDuration(videoValue.position)} / ${_formatDuration(videoValue.duration)}',
                      style: robotoRegular.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _VideoPlayerStatusView extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  const _VideoPlayerStatusView({
    required this.child,
    required this.borderRadius,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Center(child: child),
      ),
    );
  }
}
