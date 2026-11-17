import 'dart:math';

import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../theme/app_theme.dart';

/// Circular cartoon avatar.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.spec, required this.size, required this.background, this.number});
  final AvatarSpec spec;
  final double size;
  final Color background;
  final int? number;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CustomPaint(
        size: Size.square(size),
        painter: AvatarPainter(spec, background: background, number: number),
      ),
    );
  }
}

/// Draws a basketball-player bust in a unit square scaled to the canvas, so
/// it stays crisp from a 22px box-score icon to a 160px profile header.
class AvatarPainter extends CustomPainter {
  AvatarPainter(this.spec, {required this.background, this.number});
  final AvatarSpec spec;
  final Color background;
  final int? number;

  static const _ink = Color(0xFF2A1A12);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    Offset o(double x, double y) => Offset(x * u, y * u);
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * u, t * u, rr * u, b * u);
    Paint fill(Color c) => Paint()
      ..color = c
      ..isAntiAlias = true;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path oval(Rect rect) => Path()..addOval(rect);
    Path rect(Rect rect) => Path()..addRect(rect);
    Path intersect(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);

    final skin = Color(spec.skin);
    final skinShade = Color.lerp(skin, Colors.black, 0.16)!;
    final hair = Color(spec.hairColor);
    final hairDark = Color.lerp(hair, Colors.black, 0.3)!;
    final browColor = hair.computeLuminance() > 0.45 || spec.hair == HairStyle.bald
        ? Color.lerp(hair, _ink, 0.55)!
        : hair;
    final jersey = Color(spec.jersey);
    final trim = jersey.computeLuminance() > 0.5 ? const Color(0xFF1B1B1F) : Colors.white;

    // ---------------------------------------------------------- background
    final full = r(0, 0, 1, 1);
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(background, Colors.white, 0.18)!, Color.lerp(background, Colors.black, 0.22)!],
        ).createShader(full),
    );

    // ----------------------------------------------------- hair (behind)
    if (spec.hair == HairStyle.long) {
      canvas.drawRRect(RRect.fromRectAndRadius(r(0.235, 0.2, 0.765, 0.82), Radius.circular(0.14 * u)), fill(hair));
    } else if (spec.hair == HairStyle.afro) {
      canvas.drawCircle(o(0.5, 0.37), 0.315 * u, fill(hair));
    }

    // ------------------------------------------------- shoulders + jersey
    final body = Path()
      ..moveTo(0.06 * u, 1.05 * u)
      ..lineTo(0.06 * u, 0.96 * u)
      ..cubicTo(0.06 * u, 0.84 * u, 0.2 * u, 0.775 * u, 0.36 * u, 0.765 * u)
      ..lineTo(0.64 * u, 0.765 * u)
      ..cubicTo(0.8 * u, 0.775 * u, 0.94 * u, 0.84 * u, 0.94 * u, 0.96 * u)
      ..lineTo(0.94 * u, 1.05 * u)
      ..close();
    canvas.drawPath(body, fill(skin));
    final tank = Path()
      ..moveTo(0.21 * u, 1.05 * u)
      ..lineTo(0.21 * u, 0.9 * u)
      ..quadraticBezierTo(0.22 * u, 0.79 * u, 0.31 * u, 0.765 * u)
      ..lineTo(0.385 * u, 0.765 * u)
      ..quadraticBezierTo(0.5 * u, 0.9 * u, 0.615 * u, 0.765 * u)
      ..lineTo(0.69 * u, 0.765 * u)
      ..quadraticBezierTo(0.78 * u, 0.79 * u, 0.79 * u, 0.9 * u)
      ..lineTo(0.79 * u, 1.05 * u)
      ..close();
    canvas.drawPath(tank, fill(jersey));
    canvas.drawPath(tank, stroke(trim.withValues(alpha: 0.85), 0.018));
    if (number != null && u >= 40) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w900, fontSize: 0.15 * u, color: trim, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o(0.5, 0.955) - Offset(tp.width / 2, tp.height / 2));
    }

    // ------------------------------------------------------ neck, ears, head
    canvas.drawRRect(RRect.fromRectAndRadius(r(0.415, 0.58, 0.585, 0.81), Radius.circular(0.04 * u)), fill(skinShade));
    for (final x in [0.272, 0.728]) {
      canvas.drawCircle(o(x, 0.475), 0.047 * u, fill(skin));
      canvas.drawCircle(o(x, 0.475), 0.02 * u, fill(skinShade));
    }
    final headRect = r(0.27, 0.17, 0.73, 0.72);
    final head = oval(headRect);
    canvas.drawPath(head, fill(skin));

    // ------------------------------------------------------- facial hair
    switch (spec.beard) {
      case Beard.stubble:
        canvas.drawPath(intersect(head, rect(r(0, 0.535, 1, 1))), fill(hair.withValues(alpha: 0.3)));
      case Beard.full:
        final beard = Path.combine(
          PathOperation.union,
          intersect(head, rect(r(0, 0.53, 1, 1))),
          intersect(head, rect(r(0, 0.4, 0.31, 1))..addRect(r(0.69, 0.4, 1, 1))),
        );
        canvas.drawPath(beard, fill(hair));
        canvas.drawOval(r(0.435, 0.57, 0.565, 0.645), fill(skin));
      case Beard.goatee:
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.455, 0.625, 0.545, 0.715), Radius.circular(0.04 * u)), fill(hair));
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.43, 0.56, 0.57, 0.588), Radius.circular(0.014 * u)), fill(hair));
      case Beard.mustache:
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.425, 0.556, 0.575, 0.59), Radius.circular(0.016 * u)), fill(hair));
      case Beard.none:
        break;
    }

    // -------------------------------------------------------------- face
    const lx = 0.405, rx = 0.595, eyeY = 0.47;
    final brow = stroke(browColor, 0.022);
    final ink = fill(_ink);
    final inkLine = stroke(_ink, 0.022);
    if (spec.face == Face.focused) {
      // Angled down toward the nose: locked in.
      canvas.drawLine(o(lx - 0.045, 0.402), o(lx + 0.035, 0.428), brow);
      canvas.drawLine(o(rx + 0.045, 0.402), o(rx - 0.035, 0.428), brow);
    } else {
      final lift = spec.face == Face.hype ? -0.025 : 0.0;
      canvas.drawLine(o(lx - 0.042, 0.415 + lift), o(lx + 0.035, 0.405 + lift), brow);
      canvas.drawLine(o(rx + 0.042, 0.415 + lift), o(rx - 0.035, 0.405 + lift), brow);
    }
    switch (spec.face) {
      case Face.happy:
        for (final x in [lx, rx]) {
          canvas.drawPath(
            Path()
              ..moveTo((x - 0.03) * u, (eyeY + 0.012) * u)
              ..quadraticBezierTo(x * u, (eyeY - 0.03) * u, (x + 0.03) * u, (eyeY + 0.012) * u),
            inkLine,
          );
        }
      case Face.hype:
        for (final x in [lx, rx]) {
          canvas.drawCircle(o(x, eyeY), 0.04 * u, fill(Colors.white));
          canvas.drawCircle(o(x, eyeY), 0.021 * u, ink);
        }
      case Face.focused:
        for (final x in [lx, rx]) {
          canvas.drawCircle(o(x, eyeY + 0.005), 0.022 * u, ink);
        }
      default:
        for (final x in [lx, rx]) {
          canvas.drawCircle(o(x, eyeY), 0.026 * u, ink);
          canvas.drawCircle(o(x + 0.009, eyeY - 0.009), 0.008 * u, fill(Colors.white));
        }
    }
    // nose
    canvas.drawPath(
      Path()
        ..moveTo(0.488 * u, 0.53 * u)
        ..quadraticBezierTo(0.5 * u, 0.56 * u, 0.518 * u, 0.548 * u),
      stroke(skinShade, 0.016),
    );
    // mouth
    switch (spec.face) {
      case Face.smile:
        canvas.drawPath(
          Path()
            ..moveTo(0.44 * u, 0.6 * u)
            ..quadraticBezierTo(0.5 * u, 0.645 * u, 0.56 * u, 0.6 * u),
          inkLine,
        );
      case Face.happy:
        canvas.drawPath(
          Path()
            ..moveTo(0.425 * u, 0.59 * u)
            ..quadraticBezierTo(0.5 * u, 0.66 * u, 0.575 * u, 0.59 * u),
          inkLine,
        );
      case Face.grin:
        final mouth = Path()
          ..moveTo(0.43 * u, 0.592 * u)
          ..quadraticBezierTo(0.5 * u, 0.68 * u, 0.57 * u, 0.592 * u)
          ..close();
        canvas.drawPath(mouth, ink);
        canvas.drawPath(intersect(mouth, rect(r(0, 0.59, 1, 0.618))), fill(Colors.white));
      case Face.focused:
        canvas.drawLine(o(0.46, 0.615), o(0.54, 0.612), inkLine);
      case Face.hype:
        canvas.drawOval(r(0.445, 0.578, 0.555, 0.67), ink);
        canvas.drawOval(r(0.465, 0.632, 0.535, 0.665), fill(const Color(0xFFE35D6A)));
    }

    // ---------------------------------------------------------- hair (front)
    final hairOval = oval(r(0.255, 0.15, 0.745, 0.71));
    Path cap(double hairline) => intersect(hairOval, rect(r(0, 0, 1, hairline)));
    final hairPaint = fill(hair);
    switch (spec.hair) {
      case HairStyle.bald:
        canvas.drawOval(r(0.36, 0.215, 0.46, 0.27), fill(Colors.white.withValues(alpha: 0.22)));
      case HairStyle.buzz:
        canvas.drawPath(cap(0.3), fill(hair.withValues(alpha: 0.55)));
      case HairStyle.short:
        canvas.drawPath(cap(0.31), hairPaint);
        canvas.drawPath(intersect(hairOval, rect(r(0.25, 0.26, 0.3, 0.43))..addRect(r(0.7, 0.26, 0.75, 0.43))), hairPaint);
      case HairStyle.flatTop:
        canvas.drawPath(cap(0.3), hairPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.295, 0.045, 0.705, 0.29), Radius.circular(0.05 * u)), hairPaint);
        canvas.drawLine(o(0.32, 0.075), o(0.68, 0.075), stroke(Color.lerp(hair, Colors.white, 0.15)!, 0.012));
      case HairStyle.afro:
        canvas.drawPath(cap(0.29), hairPaint);
      case HairStyle.curly:
        canvas.drawPath(cap(0.29), hairPaint);
        for (var i = 0; i < 7; i++) {
          final x = 0.3 + i * 0.067;
          final y = 0.25 - 0.075 * sin(pi * (x - 0.3) / 0.4);
          canvas.drawCircle(o(x, y), 0.062 * u, hairPaint);
          canvas.drawCircle(o(x + 0.012, y + 0.008), 0.018 * u, fill(hairDark));
        }
      case HairStyle.long:
        canvas.drawPath(cap(0.3), hairPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.245, 0.24, 0.31, 0.66), Radius.circular(0.03 * u)), hairPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.69, 0.24, 0.755, 0.66), Radius.circular(0.03 * u)), hairPaint);
        canvas.drawLine(o(0.5, 0.16), o(0.47, 0.26), stroke(hairDark, 0.012));
      case HairStyle.bun:
        canvas.drawPath(cap(0.31), hairPaint);
        canvas.drawCircle(o(0.5, 0.11), 0.078 * u, hairPaint);
        canvas.drawCircle(o(0.5, 0.11), 0.078 * u, stroke(hairDark, 0.01));
      case HairStyle.mohawk:
        canvas.drawPath(cap(0.3), fill(hair.withValues(alpha: 0.35)));
        canvas.drawRRect(RRect.fromRectAndRadius(r(0.445, 0.035, 0.555, 0.31), Radius.circular(0.05 * u)), hairPaint);
    }

    // -------------------------------------------------------------- headband
    if (spec.headband != null) {
      final color = Color(spec.headband!);
      final band = intersect(oval(r(0.258, 0.15, 0.742, 0.71)), rect(r(0, 0.272, 1, 0.33)));
      canvas.drawPath(band, fill(color));
      canvas.drawPath(band, stroke(Color.lerp(color, Colors.black, 0.25)!, 0.008));
    }

    // -------------------------------------------------------------- eyewear
    switch (spec.eyewear) {
      case Eyewear.glasses:
        final frame = stroke(_ink, 0.016);
        for (final x in [lx, rx]) {
          canvas.drawCircle(o(x, eyeY), 0.056 * u, fill(Colors.white.withValues(alpha: 0.12)));
          canvas.drawCircle(o(x, eyeY), 0.056 * u, frame);
        }
        canvas.drawLine(o(lx + 0.056, eyeY), o(rx - 0.056, eyeY), frame);
        canvas.drawLine(o(0.285, eyeY - 0.01), o(lx - 0.056, eyeY), frame);
        canvas.drawLine(o(0.715, eyeY - 0.01), o(rx + 0.056, eyeY), frame);
      case Eyewear.goggles:
        canvas.drawPath(intersect(oval(r(0.258, 0.15, 0.742, 0.71)), rect(r(0, 0.452, 1, 0.49))), fill(_ink));
        for (final x in [lx, rx]) {
          final lens = RRect.fromRectAndRadius(r(x - 0.072, eyeY - 0.043, x + 0.072, eyeY + 0.047), Radius.circular(0.032 * u));
          canvas.drawRRect(lens, fill(const Color(0xFF8FD3FF).withValues(alpha: 0.42)));
          canvas.drawRRect(lens, stroke(_ink, 0.016));
        }
      case Eyewear.none:
        break;
    }
  }

  @override
  bool shouldRepaint(AvatarPainter old) => old.spec != spec || old.background != background || old.number != number;
}
