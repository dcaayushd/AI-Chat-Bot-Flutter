import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  double bottomOffset = 24,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final mediaQuery = MediaQuery.maybeOf(context);
  final bottomInset = mediaQuery?.viewInsets.bottom ?? 0;
  final bottomPadding = mediaQuery?.viewPadding.bottom ?? 0;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomInset + bottomPadding + bottomOffset,
        ),
      ),
    );
}
