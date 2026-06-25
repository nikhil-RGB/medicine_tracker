import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// "MedOcto" — a small looping mascot for the corner of the Calendar screen: a
/// slate cat/octopus in a nurse cap that idles (bob, tail-sway, blinks, the odd
/// happy squint), springs up with a hop, nibbles a cookie to crumbs, and boots
/// a tiny spinning football. Purely decorative — taps pass through.
///
/// Drawn in a fixed 230-unit design space and scaled to [size].
class CalendarMascot extends StatefulWidget {
  const CalendarMascot({super.key, this.size = 108});

  final double size;

  @override
  State<CalendarMascot> createState() => _CalendarMascotState();
}

class _CalendarMascotState extends State<CalendarMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 13))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: MascotPainter(_c.value)),
        ),
      ),
    );
  }
}

class MascotPainter extends CustomPainter {
  MascotPainter(this.t);

  /// Global loop position, 0..1.
  final double t;

  static const _bodyTop = Color(0xFF4A4A60);
  static const _bodyBot = Color(0xFF2E2E3C);
  static const _bodyFlat = Color(0xFF3A3A4D);
  static const _belly = Color(0xFF55556E);
  static const _earInner = Color(0xFF5B5B70);
  static const _tentacle = Color(0xFF33333F);
  static const _capShade = Color(0xFFE3E8EC);
  static const _red = Color(0xFFE53935);
  static const _eyeDark = Color(0xFF20202C);
  static const _nose = Color(0xFFFF9AA8);
  static const _blush = Color(0xFFFF7A90);
  static const _cookie = Color(0xFFD9A066);
  static const _cookieEdge = Color(0xFFB9824A);
  static const _chip = Color(0xFF5B3A1E);
  static const _ball = Color(0xFF7A4A23);
  static const _ballEdge = Color(0xFF5B3413);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 230.0;
    canvas.save();
    canvas.translate(size.width / 2 - 130 * k, 6 * k);
    canvas.scale(k);

    final scene = (t * 4).floor() % 4; // 0 idle, 1 jump, 2 eat, 3 kick
    final lt = (t * 4) % 1.0;
    final bob = math.sin(t * 2 * math.pi * 6.5) * 2.2;

    double jumpY = 0, bodyDown = 0, sx = 1, sy = 1;
    int expr = 0; // 0 normal, 1 happy, 2 wide, 3 determined
    double blink = 0, mouthOpen = 0, tailExtra = 0;
    bool smile = true;
    double takeoffDust = -1, landDust = -1, kickDust = -1;
    bool cookieOn = false;
    Offset cookiePos = const Offset(170, 150);
    double cookieScale = 1, bite = 0, crumbT = -1;
    bool ballOn = false;
    Offset ballOff = Offset.zero;
    double ballSpin = 0, ballTrail = 0, legAngle = 0;

    switch (scene) {
      case 0: // idle
        if (lt < 0.06) {
          blink = math.sin(lt / 0.06 * math.pi);
        } else if (lt > 0.5 && lt < 0.56) {
          blink = math.sin((lt - 0.5) / 0.06 * math.pi);
        }
        if (lt > 0.66 && lt < 0.88) {
          expr = 1; // content squint
        }
        tailExtra = math.sin(lt * math.pi * 2) * 0.12;
        break;
      case 1: // jump — anticipation, leap, landing squash
        expr = 2;
        if (lt < 0.18) {
          final a = lt / 0.18;
          sy = 1 - 0.20 * a;
          sx = 1 + 0.15 * a;
          bodyDown = 8 * a;
        } else if (lt < 0.6) {
          final a = (lt - 0.18) / 0.42;
          final air = math.sin(a * math.pi);
          jumpY = -50 * air;
          sy = 1 + 0.13 * air;
          sx = 1 - 0.09 * air;
          if (a < 0.45) takeoffDust = a / 0.45;
        } else if (lt < 0.8) {
          final a = (lt - 0.6) / 0.2;
          final sq = math.sin(a * math.pi);
          sy = 1 - 0.17 * sq;
          sx = 1 + 0.13 * sq;
          landDust = a;
        }
        break;
      case 2: // eat cookie
        expr = 1;
        smile = false;
        mouthOpen = (0.5 + 0.5 * math.sin(lt * math.pi * 12)).clamp(0.0, 1.0);
        cookieOn = lt < 0.92;
        final moveT = (lt / 0.16).clamp(0.0, 1.0);
        cookiePos = Offset.lerp(const Offset(174, 152), const Offset(149, 143), moveT)!;
        bite = ((lt - 0.22) / 0.62 * 4).clamp(0.0, 4.0);
        cookieScale = 1 - (bite / 4) * 0.3;
        crumbT = lt > 0.3 ? (lt * 5) % 1.0 : -1;
        break;
      case 3: // kick football
        expr = 3;
        ballOn = true;
        if (lt < 0.14) {
          legAngle = (lt / 0.14) * 0.30; // wind up (back)
        } else if (lt < 0.34) {
          legAngle = 0.30 + ((lt - 0.14) / 0.20) * -1.25; // swing through
        } else if (lt < 0.62) {
          legAngle = -0.95 + ((lt - 0.34) / 0.28) * 0.95; // return
        }
        if (lt < 0.28) {
          ballOff = Offset.zero;
        } else {
          final f = ((lt - 0.28) / 0.72).clamp(0.0, 1.0);
          ballOff = Offset(-82 * f, -34 * math.sin(f * math.pi));
          ballSpin = -f * 11;
          ballTrail = f < 0.55 ? 1 - f / 0.55 : 0;
        }
        if (lt > 0.28 && lt < 0.5) kickDust = (lt - 0.28) / 0.22;
        break;
    }

    final tailAngle = math.sin(t * 2 * math.pi * 1.4) * 0.2 + tailExtra;
    const groundY = 208.0;

    // shadow (shrinks while airborne)
    final sh = (1 - 0.5 * (jumpY.abs() / 50)).clamp(0.4, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(130, groundY), width: 94 * sh, height: 19 * sh),
      Paint()..color = const Color(0xFF1F2430).withOpacity(0.22 * sh),
    );

    if (takeoffDust >= 0) _dust(canvas, const Offset(130, 198), takeoffDust);
    if (landDust >= 0) _dust(canvas, const Offset(130, 198), landDust);
    if (kickDust >= 0) _dust(canvas, const Offset(112, 198), kickDust);

    if (ballOn) {
      final p = const Offset(120, 200) + ballOff;
      if (ballTrail > 0) _ballTrail(canvas, p, ballTrail);
      _drawBall(canvas, p, ballSpin);
    }

    // mascot group: bob + jump + squash about its centre
    canvas.save();
    canvas.translate(0, bob + jumpY + bodyDown);
    canvas.translate(130, 134);
    canvas.scale(sx, sy);
    canvas.translate(-130, -134);

    _tail(canvas, tailAngle);
    _feet(canvas, legAngle);
    _bodyHead(canvas);
    _cap(canvas);
    _face(canvas, expr, blink, mouthOpen, smile);
    if (cookieOn) _drawCookie(canvas, cookiePos, cookieScale, bite);
    if (crumbT >= 0) _crumbs(canvas, const Offset(150, 150), crumbT);

    canvas.restore();
    canvas.restore();
  }

  void _dust(Canvas c, Offset ctr, double p) {
    final a = (1 - p).clamp(0.0, 1.0);
    final paint = Paint()..color = const Color(0xFFCBD2CE).withOpacity(0.55 * a);
    final spread = 4 + 22 * p;
    double r(double base) => (base - base * 0.6 * p).clamp(0.6, base);
    c.drawCircle(ctr + Offset(-spread, 2), r(4), paint);
    c.drawCircle(ctr + Offset(spread, 2), r(4), paint);
    c.drawCircle(ctr + Offset(-spread * 0.5, -spread * 0.4), r(3.2), paint);
    c.drawCircle(ctr + Offset(spread * 0.5, -spread * 0.4), r(3.2), paint);
  }

  void _tail(Canvas c, double angle) {
    c.save();
    c.translate(178, 150);
    c.rotate(angle);
    c.drawPath(
      Path()
        ..moveTo(0, -9)
        ..quadraticBezierTo(28, -8, 32, 16)
        ..quadraticBezierTo(22, 26, 13, 13)
        ..quadraticBezierTo(6, 2, 0, 9)
        ..close(),
      Paint()..color = _tentacle,
    );
    c.restore();
  }

  void _feet(Canvas c, double legAngle) {
    final p = Paint()..color = _tentacle;
    Path foot(double x) => Path()
      ..moveTo(x - 6, 168)
      ..quadraticBezierTo(x - 12, 184, x - 8, 202)
      ..quadraticBezierTo(x, 208, x + 8, 202)
      ..quadraticBezierTo(x + 12, 184, x + 6, 168)
      ..close();
    c.drawPath(foot(112), p);
    c.drawPath(foot(148), p);

    // Kicking foot (front-left), rotates about its base.
    c.save();
    c.translate(116, 170);
    c.rotate(legAngle);
    c.translate(-116, -170);
    c.drawPath(
      Path()
        ..moveTo(108, 168)
        ..quadraticBezierTo(100, 186, 104, 206)
        ..quadraticBezierTo(116, 212, 126, 204)
        ..quadraticBezierTo(126, 186, 124, 168)
        ..close(),
      p,
    );
    c.restore();
  }

  void _bodyHead(Canvas c) {
    // ears
    final ear = Paint()..color = _bodyFlat;
    c.drawPath(Path()..moveTo(96, 78)..lineTo(90, 50)..lineTo(120, 66)..close(), ear);
    c.drawPath(Path()..moveTo(164, 78)..lineTo(170, 50)..lineTo(140, 66)..close(), ear);
    final inner = Paint()..color = _earInner;
    c.drawPath(Path()..moveTo(99, 72)..lineTo(96, 56)..lineTo(112, 65)..close(), inner);
    c.drawPath(Path()..moveTo(161, 72)..lineTo(164, 56)..lineTo(148, 65)..close(), inner);

    // body with a soft top-to-bottom gradient
    final body = Path()
      ..moveTo(130, 60)
      ..cubicTo(92, 60, 70, 86, 70, 120)
      ..cubicTo(70, 156, 96, 178, 130, 178)
      ..cubicTo(164, 178, 190, 156, 190, 120)
      ..cubicTo(190, 86, 168, 60, 130, 60)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(130, 58),
          const Offset(130, 182),
          const [_bodyTop, _bodyBot],
        ),
    );
    // belly patch
    c.drawOval(
        Rect.fromCenter(center: const Offset(130, 150), width: 70, height: 50), Paint()..color = _belly);
  }

  void _cap(Canvas c) {
    // soft contact shadow under the cap
    c.drawPath(
      Path()
        ..moveTo(96, 80)
        ..quadraticBezierTo(130, 70, 164, 80)
        ..quadraticBezierTo(130, 86, 96, 80)
        ..close(),
      Paint()..color = Colors.black.withOpacity(0.10),
    );
    c.drawPath(
      Path()
        ..moveTo(94, 74)
        ..quadraticBezierTo(130, 50, 166, 74)
        ..lineTo(166, 86)
        ..quadraticBezierTo(130, 70, 94, 86)
        ..close(),
      Paint()..color = Colors.white,
    );
    c.drawPath(
      Path()
        ..moveTo(94, 74)
        ..quadraticBezierTo(130, 50, 166, 74)
        ..lineTo(166, 78)
        ..quadraticBezierTo(130, 58, 94, 78)
        ..close(),
      Paint()..color = _capShade,
    );
    final cross = Paint()..color = _red;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(125, 62, 10, 3.4), const Radius.circular(1)), cross);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(128.3, 58.7, 3.4, 10), const Radius.circular(1)), cross);
  }

  void _face(Canvas c, int expr, double blink, double mouthOpen, bool smile) {
    // cheeks
    final blushP = Paint()..color = _blush.withOpacity(expr == 1 ? 0.45 : 0.3);
    c.drawCircle(const Offset(99, 134), 9.5, blushP);
    c.drawCircle(const Offset(161, 134), 9.5, blushP);

    // whiskers
    final wk = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final s in const [-1.0, 1.0]) {
      final bx = 130 + s * 31;
      c.drawLine(Offset(bx, 132), Offset(bx + s * 16, 128), wk);
      c.drawLine(Offset(bx, 137), Offset(bx + s * 17, 137), wk);
      c.drawLine(Offset(bx, 142), Offset(bx + s * 16, 146), wk);
    }

    const eyeL = Offset(112, 118);
    const eyeR = Offset(148, 118);

    if (expr == 1) {
      // happy closed eyes "^ ^"
      final p = Paint()
        ..color = _eyeDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      for (final e in const [eyeL, eyeR]) {
        c.drawPath(
          Path()
            ..moveTo(e.dx - 9, e.dy + 2)
            ..quadraticBezierTo(e.dx, e.dy - 9, e.dx + 9, e.dy + 2),
          p,
        );
      }
    } else {
      final ow = expr == 2 ? 13.0 : 11.5;
      final oh = (expr == 3 ? 9.5 : 12.0) * (1 - blink);
      for (final e in const [eyeL, eyeR]) {
        if (oh < 1.6) {
          c.drawLine(Offset(e.dx - 9, e.dy), Offset(e.dx + 9, e.dy),
              Paint()..color = _eyeDark..strokeWidth = 3..strokeCap = StrokeCap.round);
        } else {
          c.drawOval(Rect.fromCenter(center: e, width: ow * 1.85, height: oh * 2), Paint()..color = Colors.white);
          final pr = expr == 2 ? 6.0 : 5.5;
          c.drawCircle(Offset(e.dx + 1.5, e.dy + 2), pr, Paint()..color = _eyeDark);
          c.drawCircle(Offset(e.dx + 3.4, e.dy - 0.4), 2.0, Paint()..color = Colors.white);
        }
      }
      if (expr == 3 && oh >= 1.6) {
        // determined brows angled toward the centre
        final br = Paint()
          ..color = _eyeDark
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(103, 105), const Offset(118, 110), br);
        c.drawLine(const Offset(157, 105), const Offset(142, 110), br);
      }
    }

    // nose
    c.drawPath(Path()..moveTo(127, 131)..lineTo(133, 131)..lineTo(130, 135)..close(), Paint()..color = _nose);

    // mouth
    c.save();
    c.translate(130, 141);
    if (mouthOpen > 0.05) {
      c.scale(1, 0.4 + 0.6 * mouthOpen);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 10), Paint()..color = _eyeDark);
      c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 8, height: 5), Paint()..color = _blush);
    } else if (smile) {
      c.drawPath(
        Path()
          ..moveTo(-7, -1)
          ..quadraticBezierTo(0, 6, 7, -1),
        Paint()
          ..color = _eyeDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 9, height: 5), Paint()..color = _eyeDark);
    }
    c.restore();
  }

  void _drawCookie(Canvas c, Offset pos, double scale, double bite) {
    if (scale <= 0.05) return;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.scale(scale, scale);
    final disc = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 11));
    Path shape = disc;
    if (bite > 0.2) {
      final hole = Path()..addOval(Rect.fromCircle(center: const Offset(-8, -6), radius: 3 + bite * 1.9));
      shape = Path.combine(PathOperation.difference, disc, hole);
    }
    c.drawPath(shape, Paint()..color = _cookie);
    c.drawPath(
        shape,
        Paint()
          ..color = _cookieEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final chip = Paint()..color = _chip;
    c.drawCircle(const Offset(2, -2), 1.5, chip);
    c.drawCircle(const Offset(4, 4), 1.5, chip);
    c.drawCircle(const Offset(-2, 5), 1.3, chip);
    c.restore();
  }

  void _crumbs(Canvas c, Offset mouth, double phase) {
    for (var i = 0; i < 3; i++) {
      final ph = (phase + i * 0.33) % 1.0;
      final x = mouth.dx + (i - 1) * 5;
      final y = mouth.dy + 6 + ph * 16;
      c.drawCircle(Offset(x, y), 1.6, Paint()..color = _cookieEdge.withOpacity(1 - ph));
    }
  }

  void _drawBall(Canvas c, Offset pos, double spin) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(spin);
    final r = Rect.fromCenter(center: Offset.zero, width: 22, height: 15);
    c.drawOval(r, Paint()..color = _ball);
    c.drawOval(r, Paint()..color = _ballEdge..style = PaintingStyle.stroke..strokeWidth = 1.2);
    final lace = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(-5, 0), const Offset(5, 0), lace);
    for (final dx in const [-3.0, 0.0, 3.0]) {
      c.drawLine(Offset(dx, -2.5), Offset(dx, 2.5), lace);
    }
    c.restore();
  }

  void _ballTrail(Canvas c, Offset pos, double amt) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.4 * amt)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i <= 3; i++) {
      final o = pos + Offset(13.0 * i, -1.5 * i);
      c.drawLine(o, o + const Offset(8, 0), p);
    }
  }

  @override
  bool shouldRepaint(MascotPainter oldDelegate) => oldDelegate.t != t;
}
