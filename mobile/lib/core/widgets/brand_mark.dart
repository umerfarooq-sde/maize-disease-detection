import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Original MAIZEDOCTOR maize-and-leaf geometry. The native adaptive icon uses
/// the same 108-unit geometry; no external illustration or runtime asset fetch.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = AppSizing.iconTile, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MaizeMark()),
    ),
  );
}

class _MaizeMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 108, size.height / 108);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 108, 108),
        const Radius.circular(24),
      ),
      Paint()..color = AppColors.forest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(46, 23, 17, 43),
        const Radius.circular(8.5),
      ),
      Paint()..color = AppColors.highlight,
    );
    final kernels = Paint()
      ..color = AppColors.forest
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final y in [33.0, 41.0, 49.0]) {
      canvas.drawLine(Offset(51, y), Offset(58, y), kernels);
    }
    canvas.drawPath(
      Path()
        ..moveTo(54, 85)
        ..cubicTo(26, 75, 25, 54, 29, 43)
        ..cubicTo(46, 46, 55, 63, 54, 85)
        ..close(),
      Paint()..color = AppColors.leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(54, 85)
        ..cubicTo(83, 74, 83, 53, 79, 42)
        ..cubicTo(62, 46, 54, 63, 54, 85)
        ..close(),
      Paint()..color = AppColors.forestLight,
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, 56)
        ..quadraticBezierTo(47, 67, 54, 85)
        ..quadraticBezierTo(61, 66, 72, 55),
      Paint()
        ..color = AppColors.highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
