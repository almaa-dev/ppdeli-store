import 'package:flutter/material.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CustomYoutubePlayerPage extends StatelessWidget {
  final String videoUrl;
  final bool autoPlay;
  final String? title;

  const CustomYoutubePlayerPage({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
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
              child: CustomYoutubePlayerWidget(
                videoUrl: videoUrl,
                autoPlay: autoPlay,
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

class CustomYoutubePlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const CustomYoutubePlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  State<CustomYoutubePlayerWidget> createState() =>
      _CustomYoutubePlayerWidgetState();
}

class _CustomYoutubePlayerWidgetState extends State<CustomYoutubePlayerWidget> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _setController(widget.videoUrl);
  }

  @override
  void didUpdateWidget(CustomYoutubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.autoPlay != widget.autoPlay) {
      _controller?.dispose();
      _setController(widget.videoUrl);
    }
  }

  void _setController(String videoUrl) {
    final String? videoId = YoutubePlayer.convertUrlToId(videoUrl.trim());
    if (videoId != null && videoId.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(autoPlay: widget.autoPlay, mute: false),
      );
    } else {
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final YoutubePlayerController? controller = _controller;
    final ThemeData theme = Theme.of(context);
    final BorderRadius borderRadius =
        widget.borderRadius ?? BorderRadius.circular(Dimensions.radiusSmall);

    if (controller == null) {
      return _YoutubePlayerStatusView(
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

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: widget.backgroundColor ?? Colors.black,
        child: YoutubePlayer(
          controller: controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: theme.primaryColor,
          progressColors: ProgressBarColors(
            playedColor: theme.primaryColor,
            handleColor: theme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _YoutubePlayerStatusView extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  const _YoutubePlayerStatusView({
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
