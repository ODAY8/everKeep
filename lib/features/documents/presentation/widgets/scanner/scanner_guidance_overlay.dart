import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Renders a camera document framing guide overlay with glowing corner reticles,
/// subtle dimmed backdrop, and the canonical guidance prompt:
/// "Position the document inside the frame".
class ScannerGuidanceOverlay extends StatelessWidget {
  final String guidanceText;
  final bool isDetecting;

  const ScannerGuidanceOverlay({
    super.key,
    this.guidanceText = 'Position the document inside the frame',
    this.isDetecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // Document target box ratio: standard A4 aspect ratio (~1:1.414)
        final boxW = screenW * 0.84;
        final boxH = boxW * 1.35;
        final clampedH = boxH > screenH * 0.65 ? screenH * 0.65 : boxH;
        final clampedW = clampedH / 1.35;

        final targetRect = Rect.fromCenter(
          center: Offset(screenW / 2, screenH * 0.44),
          width: clampedW,
          height: clampedH,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // Darkened vignette outside target frame
            CustomPaint(
              painter: _GuidanceCutoutPainter(
                targetRect: targetRect,
                highlightColor: isDetecting
                    ? AppColors.glassAccentGreen
                    : AppColors.glassAccentPink,
              ),
            ),

            // Top Guidance Pill
            Positioned(
              top: targetRect.top - 58,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: AppRadius.radiusPill,
                    border: Border.all(
                      color: AppColors.glassBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.document_scanner_rounded,
                        size: 16,
                        color: isDetecting
                            ? AppColors.glassAccentGreen
                            : AppColors.glassAccentPink,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          guidanceText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GuidanceCutoutPainter extends CustomPainter {
  final Rect targetRect;
  final Color highlightColor;

  _GuidanceCutoutPainter({
    required this.targetRect,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dim mask with rounded cutout
    final rrect = RRect.fromRectAndRadius(targetRect, const Radius.circular(16));
    final fullRect = Offset.zero & size;
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawPath(path, maskPaint);

    // 2. Corner brackets
    final bracketPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-left
    canvas.drawLine(
      Offset(targetRect.left, targetRect.top + cornerLen),
      Offset(targetRect.left, targetRect.top + 8),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(targetRect.left, targetRect.top, 16, 16),
      3.14159,
      1.57079,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(targetRect.left + 8, targetRect.top),
      Offset(targetRect.left + cornerLen, targetRect.top),
      bracketPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(targetRect.right - cornerLen, targetRect.top),
      Offset(targetRect.right - 8, targetRect.top),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(targetRect.right - 16, targetRect.top, 16, 16),
      -1.57079,
      1.57079,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(targetRect.right, targetRect.top + 8),
      Offset(targetRect.right, targetRect.top + cornerLen),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(targetRect.left, targetRect.bottom - cornerLen),
      Offset(targetRect.left, targetRect.bottom - 8),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(targetRect.left, targetRect.bottom - 16, 16, 16),
      1.57079,
      1.57079,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(targetRect.left + 8, targetRect.bottom),
      Offset(targetRect.left + cornerLen, targetRect.bottom),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(targetRect.right - cornerLen, targetRect.bottom),
      Offset(targetRect.right - 8, targetRect.bottom),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(targetRect.right - 16, targetRect.bottom - 16, 16, 16),
      0,
      1.57079,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(targetRect.right, targetRect.bottom - 8),
      Offset(targetRect.right, targetRect.bottom - cornerLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(_GuidanceCutoutPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.highlightColor != highlightColor;
  }
}
