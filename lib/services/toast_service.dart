import 'package:flutter/material.dart';
import '../widgets/toast_widget.dart';

class ToastService {
  static void show(BuildContext context, String message,
      {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: ToastWidget(
            message: message,
            isError: isError,
            onDismiss: () {
              if (overlayEntry.mounted) {
                overlayEntry.remove();
              }
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }
}
