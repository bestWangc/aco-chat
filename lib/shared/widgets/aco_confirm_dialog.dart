import 'package:flutter/cupertino.dart';

Future<bool> showAcoConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool isDestructive = false,
  bool isDefaultAction = true,
  EdgeInsets contentPadding = EdgeInsets.zero,
  TextStyle? cancelTextStyle,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(padding: contentPadding, child: Text(message)),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          textStyle: cancelTextStyle,
          child: Text(cancelLabel),
        ),
        CupertinoDialogAction(
          isDefaultAction: isDefaultAction,
          isDestructiveAction: isDestructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
