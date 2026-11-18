
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class AppPullToRefresh extends StatelessWidget {
  const AppPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return CustomMaterialIndicator(
      onRefresh: onRefresh,
      backgroundColor: colors.surface,
      indicatorBuilder: (context, controller) {
        if (controller.state.isLoading) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          );
        }

        final progress = controller.value.clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Transform.rotate(
            angle: 2 * math.pi * progress,
            child: Icon(
              Icons.refresh_rounded,
              color: colors.primary,
              size: 26,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
