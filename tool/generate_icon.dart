import 'dart:ui' as ui;
import 'dart:io';

void main() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 1024, 1024));
  const double size = 1024;

  // Gradient background
  final bgPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(size, size),
      [
        const Color(0xFF5C7A5C),
        const Color(0xFF7A9E7E),
        const Color(0xFFA8C490),
        const Color(0xFFD4DDB8),
        const Color(0xFFE8DFC0),
      ],
      [0.0, 0.35, 0.65, 0.85, 1.0],
    );

  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

  final starPaint = Paint()
    ..color = const Color(0xFFFAF7F2)
    ..style = PaintingStyle.fill;

  const cx = size / 2;
  const cy = size / 2;
  // Star is now 25% of icon size instead of 46% — much smaller
  const arm = size * 0.25;
  const w = size * 0.055;

  final vertical = Path()
    ..moveTo(cx, cy - arm)
    ..lineTo(cx + w, cy)
    ..lineTo(cx, cy + arm)
    ..lineTo(cx - w, cy)
    ..close();
  canvas.drawPath(vertical, starPaint);

  final horizontal = Path()
    ..moveTo(cx - arm, cy)
    ..lineTo(cx, cy - w)
    ..lineTo(cx + arm, cy)
    ..lineTo(cx, cy + w)
    ..close();
  canvas.drawPath(horizontal, starPaint);

  canvas.drawCircle(
    const Offset(cx, cy),
    size * 0.022,
    starPaint,
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(1024, 1024);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

  await File('assets/icon/nurlify_icon.png')
      .writeAsBytes(bytes!.buffer.asUint8List());

  print('Icon generated');
  exit(0);
}
