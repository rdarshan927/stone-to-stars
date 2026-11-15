import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Stone to Stars brand mark: a faceted stone (amber) whose upper edge rises
/// into a four-point star (ice-blue). Pure vector, drawn with [CustomPainter].
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stone to Stars logo',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: _BrandMarkPainter()),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Rounded container ring.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..color = AppColors.borderStrong;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.025, h * 0.025, w * 0.95, h * 0.95),
        Radius.circular(w * 0.28),
      ),
      ring,
    );

    // Stone: low faceted polygon along the bottom.
    final stone = Path()
      ..moveTo(w * 0.20, h * 0.78)
      ..lineTo(w * 0.30, h * 0.60)
      ..lineTo(w * 0.52, h * 0.54)
      ..lineTo(w * 0.74, h * 0.62)
      ..lineTo(w * 0.82, h * 0.78)
      ..close();
    canvas.drawPath(stone, Paint()..color = AppColors.amber);

    // Single facet line for depth (flat, no gradient).
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.60)
        ..lineTo(w * 0.42, h * 0.78)
        ..moveTo(w * 0.52, h * 0.54)
        ..lineTo(w * 0.58, h * 0.78),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = AppColors.onAccent.withAlpha(110),
    );

    // Four-point star above the stone.
    final cx = w * 0.52;
    final cy = h * 0.30;
    final r = w * 0.17;
    final k = r * 0.28;
    final star = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + k, cy - k)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + k, cy + k)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - k, cy + k)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - k, cy - k)
      ..close();
    canvas.drawPath(star, Paint()..color = AppColors.cyan);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
