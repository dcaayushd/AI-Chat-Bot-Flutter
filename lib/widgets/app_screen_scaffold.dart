import 'package:flutter/material.dart';
import 'package:chatbotapp/widgets/app_gradient_background.dart';

double homeIndicatorSpacing(
  BuildContext context, {
  double base = 10,
  double factor = 0.32,
  double maxExtra = 12,
}) {
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  final extra = (inset * factor).clamp(0, maxExtra).toDouble();
  return base + extra;
}

class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SizedBox.expand(
        child: AppGradientBackground(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
