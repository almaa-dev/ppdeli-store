import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_asset_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_text_field_widget.dart';
import 'package:ppdelistore/features/reels/controllers/reels_controller.dart';
import 'package:ppdelistore/features/reels/domain/models/reel_model.dart';
import 'package:ppdelistore/features/reels/widgets/reel_preview_dialog_widget.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/image_size_checker.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';

class AddReelScreen extends StatefulWidget {
  final Reel? reel;
  const AddReelScreen({super.key, this.reel});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _descriptionController = [];
  final List<FocusNode> _descriptionFocusNode = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<Language>? _languageList =
      Get.find<SplashController>().configModel!.language;
  TabController? _tabController;
  final List<Tab> _tabs = [];

  int _scheduleType = 0; // 0 = All Time, 1 = Custom Schedule
  final TextEditingController _dateRangeController = TextEditingController();
  DateTimeRange? _selectedDateRange;

  XFile? _thumbnailImage;
  XFile? _mediaFile;
  bool _isVideoFile = false;

  String? _networkThumbnailUrl;
  String? _networkVideoUrl;

  late bool _isUpdate;

  String get _maxFileSizeText {
    final double maxFileSize =
        Get.find<SplashController>().configModel!.validationConfig!.maxFileSize;
    if (maxFileSize % 1 == 0) {
      return maxFileSize.toInt().toString();
    }
    return maxFileSize.toString();
  }

  String get _imageSizeErrorText =>
      'image_size_exceeds'.trParams({'size': _maxFileSizeText});

  @override
  void initState() {
    super.initState();

    _isUpdate = widget.reel != null;

    _tabController = TabController(length: _languageList!.length, vsync: this);
    for (var language in _languageList) {
      _tabs.add(Tab(text: language.value));
      _descriptionController.add(TextEditingController());
      _descriptionFocusNode.add(FocusNode());
    }

    if (_isUpdate) {
      _prefillForm();
    }
  }

  void _prefillForm() {
    final reel = widget.reel!;

    _descriptionController[0].text = reel.description ?? '';

    _networkThumbnailUrl = reel.thumbnailFullUrl;
    _networkVideoUrl = reel.videoFullUrl;
    if (_networkVideoUrl != null && _networkVideoUrl!.isNotEmpty) {
      _isVideoFile = true;
    }

    if (reel.isAlwaysVisible == true) {
      _scheduleType = 0;
    } else {
      _scheduleType = 1;
      if (reel.startDate != null && reel.endDate != null) {
        try {
          DateTime start = DateTime.parse(reel.startDate!);
          DateTime end = DateTime.parse(reel.endDate!);
          _selectedDateRange = DateTimeRange(start: start, end: end);
          String firstDate = DateConverterHelper.stringToMDY(start.toString());
          String lastDate = DateConverterHelper.stringToMDY(end.toString());
          _dateRangeController.text = '$firstDate - $lastDate';
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _descriptionController) {
      controller.dispose();
    }
    for (var node in _descriptionFocusNode) {
      node.dispose();
    }
    _dateRangeController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: _isUpdate ? 'update_reel'.tr : 'create_reel'.tr,
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReelInfoSection(),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    _buildReelValidationSection(),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    _buildThumbnailUploadSection(),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    _buildFileUploadSection(),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  ],
                ),
              ),
            ),
          ),

          _buildBottomButtons(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _showPreviewDialog,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const CustomAssetImageWidget(
                Images.reelPreview,
                height: 100,
                width: 100,
              ),
              Positioned(
                bottom: -15,
                left: -3,
                right: -3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    color: Theme.of(context).primaryColor,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 14,
                        color: Theme.of(context).cardColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'preview'.tr,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReelInfoSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reel_info'.tr,
            style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'upload_a_video_and_add_details_to_create_a_new_reel_for_your_store'
                .tr,
            style: robotoRegular.copyWith(
              color: Theme.of(context).disabledColor,
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: TabBar(
                    tabAlignment: TabAlignment.start,
                    controller: _tabController,
                    indicatorColor: Theme.of(context).primaryColor,
                    indicatorWeight: 3,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Theme.of(context).disabledColor,
                    unselectedLabelStyle: robotoRegular.copyWith(
                      color: Theme.of(context).disabledColor,
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                    labelStyle: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Theme.of(context).primaryColor,
                    ),
                    labelPadding: const EdgeInsets.only(
                      right: Dimensions.radiusDefault,
                    ),
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: _tabs,
                    onTap: (int? value) {
                      setState(() {});
                    },
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(
                    bottom: Dimensions.paddingSizeDefault,
                  ),
                  child: Divider(height: 0),
                ),

                CustomTextFieldWidget(
                  hintText: 'short_description'.tr,
                  labelText:
                      '${'short_description'.tr} (${_tabController!.index == 0 ? 'default'.tr : _languageList![_tabController!.index].value ?? ''})',
                  controller: _descriptionController[_tabController!.index],
                  focusNode: _descriptionFocusNode[_tabController!.index],
                  capitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  showTitle: false,
                  required: _tabController!.index == 0,
                  maxLength: 100,
                  validator: (value) {
                    if (_tabController!.index == 0 &&
                        (value == null || value.trim().isEmpty)) {
                      return 'enter_short_description'.tr;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelValidationSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reel_validation'.tr,
            style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'here_you_can_setup_the_food_information'.tr,
            style: robotoRegular.copyWith(
              color: Theme.of(context).disabledColor,
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            child: Row(
              children: [
                Expanded(
                  child: _buildRadioOption(
                    title: 'all_time'.tr,
                    subtitle:
                        'this_reel_will_always_be_visible_to_customers'.tr,
                    value: 0,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: _buildRadioOption(
                    title: 'custom_schedule'.tr,
                    subtitle: 'specify_the_start_and_end_dates_for_the_reel'.tr,
                    value: 1,
                  ),
                ),
              ],
            ),
          ),

          if (_scheduleType == 1) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),

            InkWell(
              onTap: () async {
                DateTimeRange? dateTimeRange = await showDateRangePicker(
                  initialEntryMode: DatePickerEntryMode.calendar,
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(3000),
                  currentDate: DateTime.now(),
                  initialDateRange: _selectedDateRange,
                );

                if (dateTimeRange != null) {
                  _selectedDateRange = dateTimeRange;
                  String firstDate = DateConverterHelper.stringToMDY(
                    dateTimeRange.start.toString(),
                  );
                  String lastDate = DateConverterHelper.stringToMDY(
                    dateTimeRange.end.toString(),
                  );
                  _dateRangeController.text = '$firstDate - $lastDate';
                  setState(() {});
                }
              },
              child: CustomTextFieldWidget(
                controller: _dateRangeController,
                hintText: 'select_date'.tr,
                labelText: 'select_date'.tr,
                showTitle: false,
                isEnabled: false,
                suffixChild: Icon(
                  Icons.date_range_rounded,
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required int value,
  }) {
    final bool isSelected = _scheduleType == value;
    return InkWell(
      onTap: () {
        setState(() {
          _scheduleType = value;
        });
      },
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<int>(
            value: value,
            groupValue: _scheduleType,
            onChanged: (int? val) {
              setState(() {
                _scheduleType = val!;
              });
            },
            activeColor: Theme.of(context).primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: Dimensions.paddingSizeExtraSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: isSelected
                          ? Theme.of(context).textTheme.bodyLarge!.color
                          : Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: Theme.of(context).disabledColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailUploadSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'upload_thumbnail_image'.tr,
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
              ),
              Text(
                ' *'.tr,
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'thumbnail_image_format'.trParams({'size': _maxFileSizeText}),
            style: robotoRegular.copyWith(
              color: Theme.of(context).disabledColor,
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Center(
            child: DottedBorder(
              options: RoundedRectDottedBorderOptions(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
                strokeWidth: 1,
                radius: const Radius.circular(Dimensions.radiusDefault),
              ),
              child: InkWell(
                onTap: _pickThumbnailImage,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.04),
                  ),
                  child: _thumbnailImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          child: Image.file(
                            File(_thumbnailImage!.path),
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _networkThumbnailUrl != null &&
                            _networkThumbnailUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          child: CustomImageWidget(
                            image: _networkThumbnailUrl!,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeExtraSmall,
                            ),
                            Text(
                              'click_to_add'.tr,
                              style: robotoRegular.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontSize: Dimensions.fontSizeSmall,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadSection() {
    final reelsModule = Get.find<SplashController>().configModel!.reelsModule;
    final int maxSizeMb = reelsModule?.reelsMaxUploadSizeMb ?? 50;
    final int maxDuration = reelsModule?.reelsMaxDuration ?? 50;
    final String durationUnit = reelsModule?.reelsMaxDurationUnit ?? 'min';

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'upload_a_file'.tr,
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
              ),
              Text(
                ' *'.tr,
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'mp4_mov_jpg_png'.tr,
            style: robotoRegular.copyWith(
              color: Theme.of(context).disabledColor,
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${'max_size'.tr}: $maxSizeMb MB · ${'max_duration'.tr}: $maxDuration $durationUnit (9:16 ${'recommended'.tr})',
            style: robotoRegular.copyWith(
              color: Theme.of(context).disabledColor,
              fontSize: Dimensions.fontSizeSmall,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          DottedBorder(
            options: RoundedRectDottedBorderOptions(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
              strokeWidth: 1,
              radius: const Radius.circular(Dimensions.radiusDefault),
            ),
            child: InkWell(
              onTap: _pickMediaFile,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  color: Theme.of(
                    context,
                  ).disabledColor.withValues(alpha: 0.04),
                ),
                child: _mediaFile != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam,
                            color: Theme.of(context).primaryColor,
                            size: 36,
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Flexible(
                            child: Text(
                              _mediaFile!.name,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).disabledColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : _networkVideoUrl != null && _networkVideoUrl!.isNotEmpty
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam,
                            color: Theme.of(context).primaryColor,
                            size: 36,
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Flexible(
                            child: Text(
                              'video_uploaded'.tr,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).disabledColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Text(
                            'tap_to_change'.tr,
                            style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeExtraSmall,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: Theme.of(context).primaryColor,
                            size: 28,
                          ),
                          const SizedBox(
                            height: Dimensions.paddingSizeExtraSmall,
                          ),
                          Text(
                            'click_to_add'.tr,
                            style: robotoRegular.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontSize: Dimensions.fontSizeSmall,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Row(
            children: [
              Expanded(
                child: CustomButtonWidget(
                  buttonText: 'reset'.tr,
                  color: Theme.of(
                    context,
                  ).disabledColor.withValues(alpha: 0.15),
                  textColor: Theme.of(context).textTheme.bodyLarge!.color,
                  onPressed: _resetForm,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeDefault),
              Expanded(
                child: GetBuilder<ReelsController>(
                  builder: (reelsController) {
                    return CustomButtonWidget(
                      isLoading: reelsController.isSubmitting,
                      buttonText: _isUpdate ? 'update'.tr : 'save'.tr,
                      onPressed: reelsController.isSubmitting
                          ? null
                          : _submitForm,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickThumbnailImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final double imageSize = await ImageSize.getImageSizeFromXFile(image);
      final SplashController splashController = Get.find<SplashController>();
      if (imageSize >
          splashController.configModel!.validationConfig!.maxFileSize) {
        showCustomSnackBar(_imageSizeErrorText);
        return;
      }

      setState(() {
        _thumbnailImage = image;
      });
    }
  }

  Future<void> _pickMediaFile() async {
    final ImagePicker picker = ImagePicker();
    XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final reelsModule = Get.find<SplashController>().configModel!.reelsModule;
      final int maxSizeMb = reelsModule?.reelsMaxUploadSizeMb ?? 50;
      final int fileSizeInBytes = await File(video.path).length();
      final double fileSizeInMb = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMb > maxSizeMb) {
        showCustomSnackBar('${'video_size_exceeds'.tr} $maxSizeMb MB');
        return;
      }

      setState(() {
        _mediaFile = video;
        _isVideoFile = true;
      });
    }
  }

  void _showPreviewDialog() {
    Get.dialog(
      ReelPreviewDialogWidget(
        description: _descriptionController[0].text,
        thumbnailImage: _thumbnailImage,
        mediaFile: _isVideoFile ? _mediaFile : null,
        isVideoFile: _isVideoFile && _mediaFile != null,
        networkThumbnailUrl: _thumbnailImage == null
            ? _networkThumbnailUrl
            : null,
        networkVideoUrl: _mediaFile == null ? _networkVideoUrl : null,
      ),
      barrierDismissible: true,
      useSafeArea: true,
    );
  }

  void _resetForm() {
    setState(() {
      for (var controller in _descriptionController) {
        controller.clear();
      }
      _dateRangeController.clear();
      _selectedDateRange = null;
      _scheduleType = 0;
      _thumbnailImage = null;
      _mediaFile = null;
      _isVideoFile = false;
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (!_isUpdate && _thumbnailImage == null) {
        showCustomSnackBar('upload_thumbnail_image'.tr);
        return;
      }
      if (!_isUpdate && _mediaFile == null) {
        showCustomSnackBar('upload_a_file'.tr);
        return;
      }
      if (_scheduleType == 1 && _selectedDateRange == null) {
        showCustomSnackBar('select_date'.tr);
        return;
      }

      Get.find<ReelsController>().submitReel(
        descriptionControllers: _descriptionController,
        languageList: _languageList!,
        thumbnail: _thumbnailImage,
        video: _mediaFile,
        isAlwaysVisible: _scheduleType == 0,
        dateRange: _selectedDateRange,
        reelId: _isUpdate ? widget.reel!.id : null,
      );
    }
  }
}
