import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_video_player_widget.dart';
import 'package:ppdelistore/features/ai/widgets/animated_border_container.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/helper/functions.dart';
import 'package:ppdelistore/helper/validate_check.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:video_player/video_player.dart';

class ProductVideoWidget extends StatefulWidget {
  final StoreController storeController;
  final Item? item;
  const ProductVideoWidget({
    super.key,
    required this.storeController,
    this.item,
  });

  @override
  State<ProductVideoWidget> createState() => _ProductVideoWidgetState();
}

class _ProductVideoWidgetState extends State<ProductVideoWidget> {
  late final TextEditingController _linkController;
  late bool _isUploadMode;
  bool _showSavedVideoPreview = true;
  VideoPlayerController? _previewController;
  Future<void>? _previewInitialization;
  String? _previewVideoPath;

  @override
  void initState() {
    super.initState();
    final String? videoFullUrl = widget.item?.videoFullUrl?.trim();
    final String? videoLink = widget.item?.videoLink?.trim();

    if (videoFullUrl != null && videoFullUrl.isNotEmpty) {
      _isUploadMode = true;
      _showSavedVideoPreview = true;
      _linkController = TextEditingController(text: '');
    } else if (videoLink != null && videoLink.isNotEmpty) {
      _isUploadMode = false;
      _showSavedVideoPreview = false;
      _linkController = TextEditingController(text: videoLink);
    } else {
      _isUploadMode = widget.storeController.toggleVideo;
      _showSavedVideoPreview = false;
      _linkController = TextEditingController(text: '');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.storeController.setToggleVideo(_isUploadMode);
      widget.storeController.setVideoLink(
        _isUploadMode
            ? null
            : (_linkController.text.trim().isNotEmpty
                  ? _linkController.text.trim()
                  : null),
      );
    });

    _syncVideoPreview();
  }

  @override
  void didUpdateWidget(covariant ProductVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVideoPreview();
  }

  void _syncVideoPreview() {
    final String? videoPath = widget.storeController.rawVideo?.path;
    final String? remoteVideoUrl = _savedVideoFullUrl();

    if (videoPath == null && remoteVideoUrl == null) {
      _disposeVideoPreview();
      return;
    }

    final String previewKey = videoPath != null
        ? 'file:$videoPath'
        : 'network:$remoteVideoUrl';
    if (previewKey == _previewVideoPath && _previewController != null) {
      return;
    }

    _disposeVideoPreview();

    final VideoPlayerController controller = videoPath != null
        ? VideoPlayerController.file(File(videoPath))
        : VideoPlayerController.networkUrl(Uri.parse(remoteVideoUrl!));
    _previewController = controller;
    _previewVideoPath = previewKey;
    _previewInitialization = controller
        .initialize()
        .then((_) async {
          await controller.setLooping(false);
          await controller.setVolume(0);
          await controller.pause();
          await controller.seekTo(Duration.zero);

          if (mounted && identical(_previewController, controller)) {
            setState(() {});
          }
        })
        .catchError((_) {
          if (mounted && identical(_previewController, controller)) {
            setState(() {});
          }
        });
  }

  void _disposeVideoPreview() {
    final VideoPlayerController? controller = _previewController;
    _previewController = null;
    _previewInitialization = null;
    _previewVideoPath = null;
    controller?.dispose();
  }

  String _formatLimit(double limit) {
    return limit % 1 == 0 ? limit.toInt().toString() : limit.toString();
  }

  void _openVideoPlayerPage(StoreController storeController) {
    final String? videoPath = storeController.rawVideo?.path;
    final String? remoteVideoUrl = _savedVideoFullUrl();

    if (videoPath == null && remoteVideoUrl == null) {
      return;
    }

    final bool isNetwork = videoPath == null;
    Get.to(
      () => CustomVideoPlayerPage(
        filePath: isNetwork ? remoteVideoUrl! : videoPath,
        isNetwork: isNetwork,
        title: isNetwork
            ? (remoteVideoUrl ?? storeController.rawVideo?.name)
            : storeController.rawVideo?.name,
      ),
    );
  }

  String? _savedVideoFullUrl() {
    if (!_isUploadMode || !_showSavedVideoPreview) {
      return null;
    }

    final String? fullUrl = widget.item?.videoFullUrl?.trim();
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return fullUrl;
    }

    return null;
  }

  @override
  void dispose() {
    _disposeVideoPreview();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBorderContainer(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      isLoading: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(widget.storeController),
          const SizedBox(
            height:
                Dimensions.paddingSizeDefault +
                Dimensions.paddingSizeExtraSmall,
          ),

          _buildToggleRow(widget.storeController),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Center(child: _buildContentArea(widget.storeController)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(StoreController storeController) {
    final theme = Theme.of(context);
    final String videoLimit = _formatLimit(
      Get.find<SplashController>()
          .configModel!
          .validationConfig!
          .productVideoMaxFileSize,
    );
    final bool hasVideoError =
        _isUploadMode &&
        storeController.rawVideo != null &&
        !storeController.isVideoValid;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Video',
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall - 1),
              RichText(
                text: TextSpan(
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall + 1,
                    color: theme.disabledColor,
                  ),
                  children: [
                    const TextSpan(text: 'Upload one optional video'),
                    if (_isUploadMode) ...[
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: 'MP4, Webp',
                        style: robotoBold.copyWith(
                          fontSize: Dimensions.fontSizeSmall + 1,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const TextSpan(text: '. Size : '),
                      TextSpan(
                        text: 'Max $videoLimit MB',
                        style: robotoBold.copyWith(
                          fontSize: Dimensions.fontSizeSmall + 1,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasVideoError) ...[
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 22,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleRow(StoreController storeController) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RadioOption(
              label: 'Upload Video',
              selected: _isUploadMode,
              onTap: () => _setUploadMode(true),
            ),
          ),
          Expanded(
            child: _RadioOption(
              label: 'Upload Video Link',
              selected: !_isUploadMode,
              onTap: () => _setUploadMode(false),
            ),
          ),
        ],
      ),
    );
  }

  void _setUploadMode(bool isUploadMode) {
    if (_isUploadMode == isUploadMode) {
      return;
    }

    setState(() {
      _isUploadMode = isUploadMode;
    });

    widget.storeController.setToggleVideo(isUploadMode);
    widget.storeController.setVideoLink(
      isUploadMode
          ? null
          : (_linkController.text.trim().isNotEmpty
                ? _linkController.text.trim()
                : null),
    );
    _syncVideoPreview();
  }

  Widget _buildContentArea(StoreController storeController) {
    if (!_isUploadMode) {
      return _buildLinkInput(storeController);
    }

    if (storeController.rawVideo != null) {
      return _buildUploadedPreview(storeController);
    }

    final String? remoteVideoUrl = _savedVideoFullUrl();
    if (remoteVideoUrl != null) {
      return _buildUploadedPreview(
        storeController,
        remoteVideoUrl: remoteVideoUrl,
      );
    }

    return _buildDropZone(storeController);
  }

  Widget _buildDropZone(StoreController storeController) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      key: const ValueKey('dropzone'),
      children: [
        GestureDetector(
          onTap: () => storeController.pickVideo(),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: theme.disabledColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            child: DottedBorder(
              options: RoundedRectDottedBorderOptions(
                radius: const Radius.circular(Dimensions.radiusDefault),
                dashPattern: const [8, 4],
                strokeWidth: 1.5,
                color: theme.disabledColor.withValues(alpha: 0.35),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 36,
                          color: theme.disabledColor.withValues(alpha: 0.7),
                        ),
                        Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_circle,
                            size: 16,
                            color: theme.disabledColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall - 2),
                    Text(
                      'Add Video',
                      style: robotoMedium.copyWith(
                        color: theme.primaryColor,
                        fontSize: Dimensions.fontSizeSmall + 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall + 2),
        RichText(
          text: TextSpan(
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: theme.disabledColor,
            ),
            children: [
              const TextSpan(text: 'MP4 Size : Max '),
              TextSpan(
                text:
                    '${_formatLimit(Get.find<SplashController>().configModel!.validationConfig!.productVideoMaxFileSize)} MB',
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall - 1),
      ],
    );
  }

  Widget _buildUploadedPreview(
    StoreController storeController, {
    String? remoteVideoUrl,
  }) {
    final theme = Theme.of(context);
    final bool isNetwork = storeController.rawVideo == null;
    final String displayLabel =
        storeController.rawVideo?.name ?? 'Saved video preview';
    final String? savedVideoSize = widget.item?.videoSize != null
        ? Functions.getSizeWithUnit(
            num.tryParse(widget.item?.videoSize?.toString() ?? '')?.toInt() ??
                0,
          )
        : null;

    return Column(
      key: ValueKey(isNetwork ? 'network-preview-$displayLabel' : 'preview'),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => _openVideoPlayerPage(storeController),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.disabledColor, width: 1.5),
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusDefault - 2,
                  ),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: FutureBuilder<void>(
                      future: _previewInitialization,
                      builder: (context, snapshot) {
                        return Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            _buildVideoThumbnail(
                              theme,
                              snapshot.connectionState,
                            ),
                            Center(
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: theme.cardColor.withValues(
                                    alpha: 0.88,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 24,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () {
                  if (storeController.rawVideo == null) {
                    setState(() {
                      _showSavedVideoPreview = false;
                    });
                    storeController.setRemoveSavedVideo(true, notify: false);
                    storeController.removeVideo();
                    _syncVideoPreview();
                  } else {
                    final bool hasSavedVideo =
                        widget.item?.videoFullUrl?.trim().isNotEmpty == true;
                    storeController.setRemoveSavedVideo(
                      hasSavedVideo && !_showSavedVideoPreview,
                      notify: false,
                    );
                    storeController.removeVideo();
                  }
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),

        Text(
          displayLabel,
          style: robotoSemiBold.copyWith(
            fontSize: Dimensions.fontSizeSmall + 1,
            color: theme.textTheme.bodyLarge?.color,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),

        storeController.rawVideo != null
            ? FutureBuilder(
                future: Functions.fileSize(storeController.rawVideo),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? "Preparing",
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: storeController.isVideoValid
                          ? theme.disabledColor
                          : theme.colorScheme.error,
                    ),
                  );
                },
              )
            : savedVideoSize != null
            ? Text(
                'Saved video size: $savedVideoSize',
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: theme.disabledColor,
                ),
              )
            : const SizedBox(),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),

        Text(
          'Tap preview to play',
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall - 1),
      ],
    );
  }

  Widget _buildVideoThumbnail(
    ThemeData theme,
    ConnectionState connectionState,
  ) {
    if (_previewController != null && _previewController!.value.isInitialized) {
      final Size videoSize = _previewController!.value.size;

      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoSize.width > 0 ? videoSize.width : 140,
              height: videoSize.height > 0 ? videoSize.height : 140,
              child: VideoPlayer(_previewController!),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.08)),
        ],
      );
    }

    return ColoredBox(
      color: theme.disabledColor.withValues(alpha: 0.12),
      child: Center(
        child: connectionState == ConnectionState.waiting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              )
            : Icon(
                Icons.video_file_rounded,
                size: 34,
                color: theme.disabledColor.withValues(alpha: 0.7),
              ),
      ),
    );
  }

  Widget _buildLinkInput(StoreController storeController) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('link'),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault + 1),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Provide Video Link',
                style: robotoSemiBold.copyWith(
                  fontSize: Dimensions.fontSizeSmall + 1,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          TextFormField(
            controller: _linkController,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: theme.textTheme.bodyMedium?.color,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) =>
                ValidateCheck.validateUrl(value, isRequired: false),
            onChanged: (value) {
              storeController.setVideoLink(value);
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
                vertical: Dimensions.paddingSizeExtraSmall,
              ),
              hintText: 'https://example.com/video',
              hintStyle: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: theme.disabledColor,
              ),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                borderSide: BorderSide(
                  color: theme.disabledColor.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                borderSide: BorderSide(
                  color: theme.disabledColor.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),

          Text(
            'Paste the video URL only. It will be saved with the product.',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Radio Option ─────────────────────────────────────────────────────────────

class _RadioOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.primaryColor
                      : theme.disabledColor.withValues(alpha: 0.45),
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: (selected ? robotoSemiBold : robotoRegular).copyWith(
                fontSize: Dimensions.fontSizeSmall + 1,
                color: selected
                    ? theme.textTheme.bodyLarge?.color
                    : theme.disabledColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
