import 'package:material_ui/material_ui.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  double bottomOffset = 24,
}) {
  final messenger = ScaffoldMessenger.of(context);

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
          bottomOffset,
        ),
      ),
    );
}
