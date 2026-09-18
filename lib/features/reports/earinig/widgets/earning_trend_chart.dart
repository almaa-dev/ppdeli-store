import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChartData {
  final int index;
  final String month;
  final double value;
  const ChartData(this.index, this.month, this.value);
}

class TrendChart extends StatefulWidget {
  final List<ChartData> data;
  const TrendChart({super.key, required this.data});

  @override
  State<TrendChart> createState() => _ChartDemoState();
}

class _ChartDemoState extends State<TrendChart> {
  static const int _yAxisStepCount = 5;

  @override
  Widget build(BuildContext context) {
    final double minValue = _getMinimumValue(widget.data);
    final double maxValue = _getMaximumValue(widget.data, minValue);
    final bool isFlatSeries = widget.data.every(
      (item) => item.value == widget.data.first.value,
    );
    final double axisInterval =
        ((maxValue - _yAxisStepCount - minValue) / _yAxisStepCount).clamp(
          1,
          double.infinity,
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withAlpha(10),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Theme.of(context).hintColor.withAlpha(50)),
      ),
      child: SfCartesianChart(
        margin: EdgeInsets.zero,

        /// ── Y-Axis ──────────────────────────────────────────────
        primaryYAxis: NumericAxis(
          title: AxisTitle(
            text: 'amount'.tr,
            textStyle: TextStyle(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          minimum: minValue,
          maximum: maxValue + (axisInterval * 10 / 100),
          interval: axisInterval,
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          majorGridLines: MajorGridLines(
            width: 1,
            color: Theme.of(context).primaryColor,
            dashArray: const <double>[6, 4],
          ),
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            final val = details.value.toInt();
            String label;
            if (val == 0) {
              label = '0';
            } else if (val % 1000 == 0) {
              label = '${val ~/ 1000}k';
            } else if (val > 10000) {
              label = '${(val / 1000).toStringAsFixed(2)}k';
            } else {
              label = val.toString();
            }
            return ChartAxisLabel(
              label,
              TextStyle(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),

        /// ── X-Axis ──────────────────────────────────────────────
        primaryXAxis: CategoryAxis(
          interval:
              showTrendFit(widget.data.length) && widget.data.length % 2 == 1
              ? 2
              : 1,
          title: AxisTitle(
            text: 'time_period'.tr,
            textStyle: TextStyle(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          axisLine: AxisLine(width: 1, color: Theme.of(context).hintColor),
          majorTickLines: const MajorTickLines(size: 0),
          majorGridLines: const MajorGridLines(width: 0),
          labelPlacement: LabelPlacement.onTicks,
          labelStyle: TextStyle(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
            fontWeight: FontWeight.w500,
          ),
          maximumLabels: 3,
          axisLabelFormatter: (details) {
            final index = details.value.toInt();
            final label = widget.data[index].month;

            return ChartAxisLabel(
              labelFormate(label),
              TextStyle(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).hintColor,
              ),
            );
          },
        ),

        /// ── Series ──────────────────────────────────────────────
        series: <CartesianSeries>[
          if (isFlatSeries)
            AreaSeries<ChartData, String>(
              dataSource: widget.data,
              xValueMapper: (d, _) => d.index.toString(),
              yValueMapper: (d, _) => d.value,
              color: Theme.of(context).primaryColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withAlpha(100),
                  Theme.of(context).primaryColor.withAlpha(0),
                ],
              ),
              borderColor: Theme.of(context).primaryColor,
              borderWidth: 2.5,
              markerSettings: const MarkerSettings(isVisible: false),
              dataLabelSettings: const DataLabelSettings(isVisible: false),
            )
          else
            SplineAreaSeries<ChartData, String>(
              dataSource: widget.data,
              xValueMapper: (d, _) => d.index.toString(),
              yValueMapper: (d, _) => d.value,
              splineType: SplineType.cardinal,
              cardinalSplineTension: 0.3,
              color: Theme.of(context).primaryColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withAlpha(100),
                  Theme.of(context).primaryColor.withAlpha(0),
                ],
              ),
              borderColor: Theme.of(context).primaryColor,
              borderWidth: 2.5,
              markerSettings: const MarkerSettings(isVisible: false),
              dataLabelSettings: const DataLabelSettings(isVisible: false),
            ),
        ],
      ),
    );
  }

  double _getMaximumValue(List<ChartData> data, double minValue) {
    double maxValue = -double.infinity;
    data.map((value) {
      if (maxValue < value.value) {
        maxValue = value.value;
      }
    }).toList();
    return maxValue.clamp(minValue, double.infinity) + _yAxisStepCount;
  }

  double _getMinimumValue(List<ChartData> data) {
    double minValue = double.infinity;
    data.map((value) {
      if (minValue > value.value) {
        minValue = value.value;
      }
    }).toList();
    return minValue;
  }

  String labelFormate(String value) {
    if (value.split(" ").length > 2) {
      final list = value.split(" ");
      list.removeLast();
      return list.join(" ");
    }
    return value;
  }
}

bool showTrendFit(int length) {
  return length <= 12 || (length % 2 == 1);
}
