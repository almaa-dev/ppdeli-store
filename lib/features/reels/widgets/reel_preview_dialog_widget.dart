import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:video_player/video_player.dart';

class ReelPreviewDialogWidget extends StatefulWidget {
  final String? description;
  final XFile? thumbnailImage;
  final XFile? mediaFile;
  final bool isVideoFile;
  final String? networkThumbnailUrl;
  final String? networkVideoUrl;

  const ReelPreviewDialogWidget({
    super.key,
    this.description,
    this.thumbnailImage,
    this.mediaFile,
    this.isVideoFile = false,
    this.networkThumbnailUrl,
    this.networkVideoUrl,
  });

  @override
  State<ReelPreviewDialogWidget> createState() =>
      _ReelPreviewDialogWidgetState();
}

class _ReelPreviewDialogWidgetState extends State<ReelPreviewDialogWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _hasStartedPlayback = false;

  bool get _hasNetworkVideo =>
      widget.networkVideoUrl != null && widget.networkVideoUrl!.isNotEmpty;
  bool get _hasNetworkThumbnail =>
      widget.networkThumbnailUrl != null &&
      widget.networkThumbnailUrl!.isNotEmpty;
  bool get _hasVideoSource =>
      (widget.isVideoFile && widget.mediaFile != null) || _hasNetworkVideo;
  bool get _hasThumbnailSource =>
      widget.thumbnailImage != null || _hasNetworkThumbnail;

  @override
  void initState() {
    super.initState();
    if (widget.isVideoFile && widget.mediaFile != null) {
      _initializeVideo();
    } else if (_hasNetworkVideo) {
      _initializeNetworkVideo();
    }
  }

  Future<void> _initializeNetworkVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.networkVideoUrl!),
    );
    try {
      await _videoController!.initialize();
      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoInitialize: true,
          aspectRatio: _videoController!.value.aspectRatio,
          autoPlay: false,
          looping: true,
          showControls: false,
        );
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(File(widget.mediaFile!.path));
    try {
      await _videoController!.initialize();
      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoInitialize: true,
          aspectRatio: _videoController!.value.aspectRatio,
          autoPlay: false,
          looping: true,
          showControls: false,
        );
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = Get.find<ProfileController>().profileModel?.stores?.first;
    final String storeName = store?.name ?? '';
    final String? storeLogo = store?.logoFullUrl;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: SizedBox(
        width: double.infinity,
        height: Get.size.height * 0.75,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background media
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: _buildFullScreenMedia(context),
            ),

            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(Dimensions.radiusLarge),
                    bottomRight: Radius.circular(Dimensions.radiusLarge),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),

            // Right side action icons
            Positioned(
              right: Dimensions.paddingSizeSmall,
              bottom: 100,
              child: Column(
                children: [
                  _buildActionIcon(Icons.thumb_up_alt_outlined, context),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  _buildActionIcon(Icons.remove_red_eye_outlined, context),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ],
              ),
            ),

            // Bottom store info + description
            Positioned(
              bottom: 20,
              left: Dimensions.paddingSizeDefault,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipOval(
                          child: storeLogo != null && storeLogo.isNotEmpty
                              ? CustomImageWidget(
                                  image: storeLogo,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey.shade700,
                                  child: const Icon(
                                    Icons.store,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Flexible(
                        child: Text(
                          storeName,
                          style: robotoBold.copyWith(
                            color: Colors.white,
                            fontSize: Dimensions.fontSizeDefault,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(
                    widget.description ?? '',
                    style: robotoRegular.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: Dimensions.fontSizeSmall,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Keep the thumbnail visible until the first play action.
            if (_hasVideoSource)
              Positioned.fill(
                bottom: 70,
                child: GestureDetector(
                  onTap: _handleVideoTap,
                  behavior: HitTestBehavior.translucent,
                  child: _buildVideoOverlayAction(),
                ),
              ),

            // Close button
            Positioned(
              top: Dimensions.paddingSizeSmall,
              right: Dimensions.paddingSizeSmall,
              child: InkWell(
                onTap: () => Get.back(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  void _handleVideoTap() {
    final VideoPlayerController? controller = _videoController;
    if (!_isVideoInitialized || controller == null) {
      return;
    }

    if (!_hasStartedPlayback) {
      setState(() {
        _hasStartedPlayback = true;
      });
      controller.play();
      return;
    }

    if (controller.value.position >= controller.value.duration) {
      controller.seekTo(Duration.zero);
    }

    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  Widget _buildVideoOverlayAction() {
    final bool isPlaying = _videoController?.value.isPlaying ?? false;
    if (isPlaying) return const SizedBox();

    return Center(
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: _isVideoInitialized
            ? const Icon(Icons.play_arrow, color: Colors.white, size: 40)
            : const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _buildFullScreenMedia(BuildContext context) {
    final bool shouldShowThumbnailFirst =
        !_hasStartedPlayback && _hasThumbnailSource;
    // Video from local file or network
    if (_isVideoInitialized &&
        _videoController != null &&
        !shouldShowThumbnailFirst) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // Thumbnail from local file
    if (widget.thumbnailImage != null) {
      return Image.file(
        File(widget.thumbnailImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Thumbnail from network
    if (_hasNetworkThumbnail) {
      return CustomImageWidget(
        image: widget.networkThumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white38, size: 72),
      ),
    );
  }
}
