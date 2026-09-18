import 'package:flutter/material.dart';
import 'package:ppdelistore/util/dimensions.dart';

class AnimatedBorderContainer extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final EdgeInsets? padding;
  const AnimatedBorderContainer({
    super.key,
    required this.child,
    required this.isLoading,
    this.padding,
  });

  @override
  State<AnimatedBorderContainer> createState() =>
      _AnimatedBorderContainerState();
}

class _AnimatedBorderContainerState extends State<AnimatedBorderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(
              width: widget.isLoading ? 2 : 0,
              color: Colors.transparent,
            ),
            gradient: widget.isLoading
                ? SweepGradient(
                    startAngle: 0.0,
                    endAngle: 6.28,
                    colors: [
                      Colors.red,
                      Colors.green,
                      Colors.red,
                      Colors.green,
                      Colors.red,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    transform: GradientRotation(_controller.value * 6.28),
                  )
                : null,
          ),
          child: Container(
            padding:
                widget.padding ??
                const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  spreadRadius: 0,
                  blurRadius: 5,
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
