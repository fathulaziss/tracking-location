import 'package:flutter/material.dart';
import 'package:tracking_location/widgets/TextWidgets.dart';

enum DialogType { permission, tracking }

Future<bool> showCustomDialog(BuildContext context, DialogType type) async {
  // Define content dynamically based on type
  final isPermission = type == DialogType.permission;

  final String title = isPermission
      ? 'Allow Location Access'
      : 'Start Location Tracking?';

  final String description = isPermission
      ? 'We need access to your location to enable tracking features and provide accurate updates.'
      : 'Your location will be tracked every minute, even when the app is minimized.';

  final String primaryText = isPermission ? 'Allow Access' : 'Start Tracking';
  final String secondaryText = isPermission ? 'Deny Access' : 'Cancel';

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location Icon
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFFF7A00), // orange tone
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Textwidgets(
                    title,
                    textAlign: TextAlign.center,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Textwidgets(
                    description,
                    textAlign: TextAlign.center,
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(height: 30),

                  // Primary Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Textwidgets(
                        primaryText,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary Button (Outlined)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFFF7A00),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Textwidgets(
                        secondaryText,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ) ??
      false;
}
