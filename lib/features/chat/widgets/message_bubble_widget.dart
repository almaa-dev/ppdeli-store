import 'package:flutter/material.dart';
import 'package:ppdelistore/features/chat/domain/models/conversation_model.dart';
import 'package:ppdelistore/features/chat/domain/models/message_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/features/chat/widgets/image_dialog_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MessageBubbleWidget extends StatelessWidget {
  final Message message;
  final Message? previousMessage;
  final Message? nextMessage;
  final User? user;
  final User? sender;
  final String userType;
  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.previousMessage,
    this.nextMessage,
    required this.user,
    required this.userType,
    required this.sender,
  });

  bool get isFirstInGroup {
    if (previousMessage == null) return true;
    return previousMessage!.senderId != message.senderId;
  }

  bool get isLastInGroup {
    if (nextMessage == null) return true;
    return nextMessage!.senderId != message.senderId;
  }

  bool get showAvatar => isLastInGroup;

  bool get showTimestamp {
    if (nextMessage == null) return true;

    DateTime currentTime = DateTime.parse(message.createdAt!);
    DateTime nextTime = DateTime.parse(nextMessage!.createdAt!);

    Duration timeDiff = nextTime.difference(currentTime).abs();
    return timeDiff.inMinutes >= 59;
  }

  BorderRadius getBorderRadius(bool isReply) {
    const double radius = Dimensions.radiusDefault;

    if (isReply) {
      if (isFirstInGroup && isLastInGroup) {
        return const BorderRadius.only(
          topRight: Radius.circular(radius),
          topLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      } else if (isFirstInGroup) {
        return const BorderRadius.only(
          topRight: Radius.circular(radius),
          topLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      } else if (isLastInGroup) {
        return const BorderRadius.only(
          topRight: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        );
      } else {
        return const BorderRadius.only(
          topRight: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      }
    } else {
      if (isFirstInGroup && isLastInGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        );
      } else if (isFirstInGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        );
      } else if (isLastInGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        );
      } else {
        return const BorderRadius.only(
          topLeft: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        );
      }
    }
  }

  String _getFileType(String url) {
    String extension = url.split('.').last.toLowerCase().split('?').first;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 'image';
    } else if (['pdf'].contains(extension)) {
      return 'pdf';
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
      return 'video';
    }
    return 'file';
  }

  Widget _getFileIcon(
    String fileType,
    BuildContext context, {
    double size = 40,
  }) {
    switch (fileType) {
      case 'pdf':
        return Icon(
          Icons.picture_as_pdf,
          size: size,
          color: Theme.of(context).hintColor,
        );
      case 'video':
        return Icon(
          Icons.videocam,
          size: size,
          color: Theme.of(context).hintColor,
        );
      case 'file':
        return Icon(
          Icons.insert_drive_file,
          size: size,
          color: Theme.of(context).hintColor,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openFile(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isReply = message.senderId == user!.id;

    return (isReply)
        ? Column(
            children: [
              Container(
                margin: EdgeInsets.only(
                  left: Dimensions.paddingSizeDefault,
                  right: Dimensions.paddingSizeDefault,
                  top: isFirstInGroup ? Dimensions.paddingSizeSmall : 2,
                  bottom: isLastInGroup ? Dimensions.paddingSizeSmall : 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Show avatar only for last message in group
                    if (showAvatar)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: CustomImageWidget(
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          image: '${user!.imageFullUrl}',
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.message != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).secondaryHeaderColor.withValues(alpha: 0.2),
                                borderRadius: getBorderRadius(true),
                              ),
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeDefault,
                              ),
                              child: Text(message.message ?? ''),
                            ),
                          if (message.message != null &&
                              message.filesFullUrl != null)
                            const SizedBox(height: 8.0),
                          if (message.filesFullUrl != null)
                            GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    childAspectRatio: 1,
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 5,
                                  ),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: message.filesFullUrl?.length,
                              itemBuilder: (BuildContext context, index) {
                                String fileUrl = message.filesFullUrl![index];
                                String fileType = _getFileType(fileUrl);

                                return message.filesFullUrl!.isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: InkWell(
                                          hoverColor: Colors.transparent,
                                          onTap: () {
                                            if (fileType == 'image') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) =>
                                                    ImageDialogWidget(
                                                      imageUrl: fileUrl,
                                                    ),
                                              );
                                            } else {
                                              _openFile(fileUrl);
                                            }
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.paddingSizeSmall,
                                            ),
                                            child: fileType == 'image'
                                                ? CustomImageWidget(
                                                    height: 100,
                                                    width: 100,
                                                    fit: BoxFit.cover,
                                                    image: fileUrl,
                                                  )
                                                : Container(
                                                    height: 100,
                                                    width: 100,
                                                    color: Theme.of(context)
                                                        .secondaryHeaderColor
                                                        .withValues(alpha: 0.2),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        _getFileIcon(
                                                          fileType,
                                                          context,
                                                          size: 40,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          fileType
                                                              .toUpperCase(),
                                                          style: robotoRegular
                                                              .copyWith(
                                                                fontSize: 10,
                                                                color: Theme.of(
                                                                  context,
                                                                ).hintColor,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Show centered timestamp only after last message in group
              if (showTimestamp)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      DateConverterHelper.localDateToIsoStringAMPM(
                        DateTime.parse(message.createdAt!),
                      ),
                      style: robotoRegular.copyWith(
                        color: Theme.of(context).hintColor,
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),
                  ),
                ),
            ],
          )
        : Column(
            children: [
              Container(
                margin: EdgeInsets.only(
                  left: Dimensions.paddingSizeDefault,
                  right: Dimensions.paddingSizeDefault,
                  top: isFirstInGroup ? Dimensions.paddingSizeSmall : 2,
                  bottom: isLastInGroup ? Dimensions.paddingSizeSmall : 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (message.message != null &&
                              message.message!.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.5),
                                borderRadius: getBorderRadius(false),
                              ),
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeDefault,
                              ),
                              child: Text(message.message ?? ''),
                            ),
                          if (message.filesFullUrl != null)
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: GridView.builder(
                                reverse: true,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      childAspectRatio: 1,
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 5,
                                    ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: message.filesFullUrl!.length,
                                itemBuilder: (BuildContext context, index) {
                                  String fileUrl = message.filesFullUrl![index];
                                  String fileType = _getFileType(fileUrl);

                                  return message.filesFullUrl!.isNotEmpty
                                      ? InkWell(
                                          onTap: () {
                                            if (fileType == 'image') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) =>
                                                    ImageDialogWidget(
                                                      imageUrl: fileUrl,
                                                    ),
                                              );
                                            } else {
                                              _openFile(fileUrl);
                                            }
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: Dimensions.paddingSizeSmall,
                                              right: 0,
                                              top:
                                                  (message.message != null &&
                                                      message
                                                          .message!
                                                          .isNotEmpty)
                                                  ? Dimensions.paddingSizeSmall
                                                  : 0,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                              child: fileType == 'image'
                                                  ? CustomImageWidget(
                                                      height: 100,
                                                      width: 100,
                                                      fit: BoxFit.cover,
                                                      image: fileUrl,
                                                    )
                                                  : Container(
                                                      height: 100,
                                                      width: 100,
                                                      color: Theme.of(
                                                        context,
                                                      ).cardColor,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          _getFileIcon(
                                                            fileType,
                                                            context,
                                                            size: 40,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            fileType
                                                                .toUpperCase(),
                                                            style: robotoRegular
                                                                .copyWith(
                                                                  fontSize: 10,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).hintColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    // Show avatar only for last message in group
                    if (showAvatar)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: CustomImageWidget(
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          image: '${sender!.imageFullUrl}',
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),
              // Show centered timestamp and seen status only after last message in group
              if (showTimestamp)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          message.isSeen == 1 ? Icons.done_all : Icons.check,
                          size: 12,
                          color: message.isSeen == 1
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).disabledColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateConverterHelper.localDateToIsoStringAMPM(
                            DateTime.parse(message.createdAt!),
                          ),
                          style: robotoRegular.copyWith(
                            color: Theme.of(context).hintColor,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
  }
}
