import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Interactive manual cropping widget with touch-draggable corner handles and
/// semi-transparent document overlay mask.
///
/// Yields a normalized [Rect] (0.0 to 1.0 coordinates) representing the cropped area.
class InteractiveCropView extends StatefulWidget {
  final Uint8List imageBytes;
  final Rect? initialCropRect;
  final ValueChanged<Rect> onCropConfirmed;
  final VoidCallback onCancel;

  const InteractiveCropView({
    super.key,
    required this.imageBytes,
    this.initialCropRect,
    required this.onCropConfirmed,
    required this.onCancel,
  });

  @override
  State<InteractiveCropView> createState() => _InteractiveCropViewState();
}

class _InteractiveCropViewState extends State<InteractiveCropView> {
  late Rect _normalizedCrop;
  Offset? _activeDragStart;
  _DragHandle? _activeHandle;
  Rect? _cropAtDragStart;

  @override
  void initState() {
    super.initState();
    _normalizedCrop = widget.initialCropRect ?? const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
  }

  void _reset() {
    setState(() {
      _normalizedCrop = const Rect.fromLTWH(0.02, 0.02, 0.96, 0.96);
    });
  }

  void _onPanStart(Offset localPos, Size containerSize) {
    final cropPixelRect = Rect.fromLTRB(
      _normalizedCrop.left * containerSize.width,
      _normalizedCrop.top * containerSize.height,
      _normalizedCrop.right * containerSize.width,
      _normalizedCrop.bottom * containerSize.height,
    );

    const hitRadius = 36.0;

    if ((localPos - cropPixelRect.topLeft).distance <= hitRadius) {
      _activeHandle = _DragHandle.topLeft;
    } else if ((localPos - cropPixelRect.topRight).distance <= hitRadius) {
      _activeHandle = _DragHandle.topRight;
    } else if ((localPos - cropPixelRect.bottomLeft).distance <= hitRadius) {
      _activeHandle = _DragHandle.bottomLeft;
    } else if ((localPos - cropPixelRect.bottomRight).distance <= hitRadius) {
      _activeHandle = _DragHandle.bottomRight;
    } else if (cropPixelRect.contains(localPos)) {
      _activeHandle = _DragHandle.body;
    } else {
      _activeHandle = null;
    }

    _activeDragStart = localPos;
    _cropAtDragStart = _normalizedCrop;
  }

  void _onPanUpdate(Offset localPos, Size containerSize) {
    if (_activeHandle == null || _activeDragStart == null || _cropAtDragStart == null) {
      return;
    }

    final delta = localPos - _activeDragStart!;
    final normalizedDelta = Offset(
      delta.dx / math.max(1, containerSize.width),
      delta.dy / math.max(1, containerSize.height),
    );

    final start = _cropAtDragStart!;
    double newLeft = start.left;
    double newTop = start.top;
    double newRight = start.right;
    double newBottom = start.bottom;

    const minSize = 0.1;

    switch (_activeHandle!) {
      case _DragHandle.topLeft:
        newLeft = (start.left + normalizedDelta.dx).clamp(0.0, newRight - minSize);
        newTop = (start.top + normalizedDelta.dy).clamp(0.0, newBottom - minSize);
        break;
      case _DragHandle.topRight:
        newRight = (start.right + normalizedDelta.dx).clamp(newLeft + minSize, 1.0);
        newTop = (start.top + normalizedDelta.dy).clamp(0.0, newBottom - minSize);
        break;
      case _DragHandle.bottomLeft:
        newLeft = (start.left + normalizedDelta.dx).clamp(0.0, newRight - minSize);
        newBottom = (start.bottom + normalizedDelta.dy).clamp(newTop + minSize, 1.0);
        break;
      case _DragHandle.bottomRight:
        newRight = (start.right + normalizedDelta.dx).clamp(newLeft + minSize, 1.0);
        newBottom = (start.bottom + normalizedDelta.dy).clamp(newTop + minSize, 1.0);
        break;
      case _DragHandle.body:
        final w = start.width;
        final h = start.height;
        newLeft = (start.left + normalizedDelta.dx).clamp(0.0, 1.0 - w);
        newTop = (start.top + normalizedDelta.dy).clamp(0.0, 1.0 - h);
        newRight = newLeft + w;
        newBottom = newTop + h;
        break;
    }

    setState(() {
      _normalizedCrop = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    });
  }

  void _onPanEnd() {
    _activeHandle = null;
    _activeDragStart = null;
    _cropAtDragStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          tooltip: 'Cancel crop',
          onPressed: widget.onCancel,
        ),
        title: Text(
          'Crop Document',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text(
              'Reset',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassAccentPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.glassAccentGreen, size: 28),
            tooltip: 'Confirm crop',
            onPressed: () => widget.onCropConfirmed(_normalizedCrop),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  color: Colors.black,
                  child: LayoutBuilder(
                    builder: (ctx, innerConstraints) {
                      final size = Size(innerConstraints.maxWidth, innerConstraints.maxHeight);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _onPanStart(d.localPosition, size),
                        onPanUpdate: (d) => _onPanUpdate(d.localPosition, size),
                        onPanEnd: (_) => _onPanEnd(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                            CustomPaint(
                              painter: _CropOverlayPainter(
                                normalizedCrop: _normalizedCrop,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              label: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.glassAccentPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => widget.onCropConfirmed(_normalizedCrop),
              icon: const Icon(Icons.done_rounded, size: 18),
              label: const Text('Apply Crop'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DragHandle { topLeft, topRight, bottomLeft, bottomRight, body }

class _CropOverlayPainter extends CustomPainter {
  final Rect normalizedCrop;

  _CropOverlayPainter({required this.normalizedCrop});

  @override
  void paint(Canvas canvas, Size size) {
    final cropPixelRect = Rect.fromLTRB(
      normalizedCrop.left * size.width,
      normalizedCrop.top * size.height,
      normalizedCrop.right * size.width,
      normalizedCrop.bottom * size.height,
    );

    // 1. Dim outside of crop rect
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullRect = Offset.zero & size;
    final path = Path()
      ..addRect(fullRect)
      ..addRect(cropPixelRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // 2. Crop border
    final borderPaint = Paint()
      ..color = AppColors.glassAccentPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropPixelRect, borderPaint);

    // 3. Rule of thirds grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final thirdW = cropPixelRect.width / 3;
    final thirdH = cropPixelRect.height / 3;

    canvas.drawLine(
      Offset(cropPixelRect.left + thirdW, cropPixelRect.top),
      Offset(cropPixelRect.left + thirdW, cropPixelRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left + 2 * thirdW, cropPixelRect.top),
      Offset(cropPixelRect.left + 2 * thirdW, cropPixelRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left, cropPixelRect.top + thirdH),
      Offset(cropPixelRect.right, cropPixelRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left, cropPixelRect.top + 2 * thirdH),
      Offset(cropPixelRect.right, cropPixelRect.top + 2 * thirdH),
      gridPaint,
    );

    // 4. Draggable corner pins
    final cornerFillPaint = Paint()..color = Colors.white;
    final cornerBorderPaint = Paint()
      ..color = AppColors.glassAccentPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const cornerRadius = 9.0;
    final corners = [
      cropPixelRect.topLeft,
      cropPixelRect.topRight,
      cropPixelRect.bottomLeft,
      cropPixelRect.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, cornerRadius, cornerFillPaint);
      canvas.drawCircle(corner, cornerRadius, cornerBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return oldDelegate.normalizedCrop != normalizedCrop;
  }
}
