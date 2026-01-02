import 'package:flutter/material.dart';

class ShowDialogBoxes {
  static void showAutoCloseSuccessDialog({
    required BuildContext context,
    required String message,
    VoidCallback? onCompleted, // Optional: What to do after closing
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // User can't click outside to close
      builder: (BuildContext dialogContext) {
        // --- AUTOMATIC TIMER ---
        Future.delayed(const Duration(seconds: 2), () {
          // 1. Close the Dialog
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }

          // 2. Execute next step (Navigate or Refresh)
          if (onCompleted != null) {
            onCompleted();
          }
        });

        // --- DIALOG UI ---
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated-style Static Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 210, 237, 245),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2585A1),
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Success!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showAutoCloseFailureDialog({
    required BuildContext context,
    required String message,
    VoidCallback? onCompleted,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // --- AUTOMATIC TIMER ---
        // Increased to 3 seconds so users have time to read the error
        Future.delayed(const Duration(seconds: 3), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
          if (onCompleted != null) {
            onCompleted();
          }
        });

        // --- DIALOG UI ---
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline, // or Icons.warning_amber
                    color: Colors.red,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Oops!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
