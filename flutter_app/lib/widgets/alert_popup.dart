import 'package:flutter/material.dart';
import '../models/hazard.dart';

class AlertPopup extends StatelessWidget {
  final Hazard hazard;
  final int distanceMeters;
  final VoidCallback onDismiss;
  final VoidCallback onVerify;

  const AlertPopup({
    super.key,
    required this.hazard,
    required this.distanceMeters,
    required this.onDismiss,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final isCritical = hazard.isCritical;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: isCritical ? const Color(0xFFB00020) : const Color(0xFFE6A700),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              hazard.isAiDetected ? Icons.sensors : Icons.pin_drop,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hazard.hazardType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$distanceMeters m ahead · ${(hazard.confidence * 100).round()}% confidence',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              tooltip: 'Verify',
              onPressed: onVerify,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Dismiss',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
