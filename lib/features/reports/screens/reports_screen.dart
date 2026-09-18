import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/reports/widgets/report_card_widget.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'reports'.tr),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: GetBuilder<ProfileController>(
          builder: (profileController) {
            return Column(
              children: [
                profileController.modulePermission!.expenseReport!
                    ? ReportCardWidget(
                        title: 'earning_report'.tr,
                        subtitle: 'revenue_overview'.tr,
                        image: Images.expense,
                        onTap: () {
                          Get.toNamed(RouteHelper.getEarningRoute());
                        },
                      )
                    : const SizedBox(),
                SizedBox(
                  height: profileController.modulePermission!.expenseReport!
                      ? Dimensions.paddingSizeDefault
                      : 0,
                ),

                profileController.modulePermission!.expenseReport!
                    ? ReportCardWidget(
                        title: 'expense_report'.tr,
                        subtitle:
                            'view_and_track_your_business_expenses_in_detail'
                                .tr,
                        image: Images.expense,
                        onTap: () => Get.toNamed(RouteHelper.getExpenseRoute()),
                      )
                    : const SizedBox(),
                SizedBox(
                  height: profileController.modulePermission!.expenseReport!
                      ? Dimensions.paddingSizeDefault
                      : 0,
                ),

                profileController.modulePermission!.vatReport!
                    ? ReportCardWidget(
                        title: 'tax_report'.tr,
                        subtitle:
                            'view_detailed_tax_calculations_and_payment_records'
                                .tr,
                        image: Images.taxReportIcon,
                        onTap: () =>
                            Get.toNamed(RouteHelper.getTaxReportRoute()),
                      )
                    : const SizedBox(),
              ],
            );
          },
        ),
      ),
    );
  }
}
