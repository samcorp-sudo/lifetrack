import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A cute little owl-chick mascot with a speech bubble that shows one
/// motivational note per day. The note changes at 12:00 AM (local time).
/// The mascot and bubble use the active season color.
///
/// The quote is picked from the calendar date, so it stays the same all day,
/// survives app restarts, and needs no storage.
class DailyQuoteBanner extends StatefulWidget {
  const DailyQuoteBanner({super.key});

  @override
  State<DailyQuoteBanner> createState() => _DailyQuoteBannerState();
}

class _DailyQuoteBannerState extends State<DailyQuoteBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Timer? _midnightTimer;
  late String _quote;

  // Edit, add or remove quotes freely. The order repeats after the last one.
  static const List<String> _quotes = [
    'Small steps every day beat big plans you never start.',
    "Your future net worth is built by today's habits.",
    'Track it, plan it, then do it. Clarity makes money calm.',
    "Don't wait for perfect timing. Start, learn, adjust.",
    'A business grows at the speed of the problems it solves.',
    "Spend on what grows you, save on what doesn't.",
    'Rest is part of the work. Come back sharper.',
    'Every customer has a story. Serve them well and the numbers follow.',
    'Discipline is a promise you keep to your future self.',
    "You don't need more time, you need clearer priorities.",
    'Progress feels slow until you look back.',
    'Be patient with growth and impatient with excuses.',
    'Cash flow is the oxygen of a business. Watch it daily.',
    'A good day is built in the first hour. Make it count.',
    'Mistakes are tuition for experience. Learn the lesson.',
    'Build assets, not just income.',
    'Focus on one thing today and do it well.',
    'Your time is your first currency. Spend it on purpose.',
    'Consistency turns ordinary effort into extraordinary results.',
    'Say no to good so you can say yes to great.',
    "Debt is a tool or a trap. Know which one you're holding.",
    'Kindness in business is never a bad investment.',
    'Hard days build the strength easy days never will.',
    'Run your own race at your own pace.',
    "Save first, spend what's left, and sleep better.",
    'Ideas are cheap. Finished work is rare.',
    'Learn a little every day and watch the gap close.',
    'Goals need dates, or they stay wishes.',
    'Protect your energy. It runs everything else.',
    'Begin before you feel ready. Readiness comes from doing.',
    "A budget isn't a limit, it's permission to spend without guilt.",
    'Great businesses are built one reliable day at a time.',
    'Be the person your future self thanks.',
    'Show up prepared, and luck has something to work with.',
    'Measure what matters, then improve it by one percent.',
    'Gratitude makes enough feel like plenty.',
    'Slow growth is still growth. Keep going.',
    'Trust is the most valuable thing you can earn in business.',
    'Money is a tool. Use it to build the life you want.',
    "Today's effort is tomorrow's freedom.",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _quote = _quoteForToday();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // If the app was in the background across midnight, refresh on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = _quoteForToday();
      if (today != _quote && mounted) setState(() => _quote = today);
      _scheduleMidnightRefresh();
    }
  }

  String _quoteForToday() {
    final now = DateTime.now();
    final day = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(2024, 1, 1))
        .inDays;
    return _quotes[day % _quotes.length];
  }

  // Fires just after the next 12:00 AM while the app is open.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() => _quote = _quoteForToday());
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final bubbleColor = s.accent.withValues(alpha: 0.16);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(
            painter: _MascotPainter(_controller, s.accent, s.accentDeep),
          ),
        ),
        CustomPaint(
          size: const Size(10, 16),
          painter: _TailPainter(bubbleColor),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "TODAY'S NOTE  ${s.emoji}",
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: s.accentText),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _quote,
                    key: ValueKey(_quote),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Speech-bubble tail (small triangle pointing at the mascot)
// ============================================================================

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}

// ============================================================================
// Mascot: an original round owl-chick, drawn with shapes.
// Gently bobs up and down and blinks once per cycle.
// Body and ear tufts follow the season color.
// ============================================================================

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.animation, this.accent, this.accentDeep)
      : super(repaint: animation);

  final Animation<double> animation;
  final Color accent;
  final Color accentDeep;

  static const Color _orange = Color(0xFFFF8A3D);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final blinking = t > 0.93;

    canvas.save();
    canvas.scale(size.width / 64);
    canvas.translate(0, math.sin(t * 2 * math.pi) * 1.6); // gentle bob

    final fill = Paint()..style = PaintingStyle.fill;

    // Ear tufts
    fill.color = accentDeep;
    canvas.drawPath(
      Path()
        ..moveTo(12, 20)
        ..lineTo(17, 5)
        ..lineTo(28, 13)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(52, 20)
        ..lineTo(47, 5)
        ..lineTo(36, 13)
        ..close(),
      fill,
    );

    // Little wings
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(7, 42), width: 8, height: 16),
        fill);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(57, 42), width: 8, height: 16),
        fill);

    // Feet
    fill.color = _orange;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(24, 60), width: 10, height: 5),
        fill);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(40, 60), width: 10, height: 5),
        fill);

    // Body
    fill.color = accent;
    canvas.drawCircle(const Offset(32, 36), 24, fill);

    // Belly
    fill.color = Color.lerp(accent, Colors.white, 0.55)!;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(32, 46), width: 28, height: 20),
        fill);

    // Eyes
    if (blinking) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = LifeTrackColors.ink;
      for (final cx in [23.0, 41.0]) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, 32), width: 12, height: 10),
          math.pi,
          math.pi,
          false,
          stroke,
        );
      }
    } else {
      fill.color = Colors.white;
      canvas.drawCircle(const Offset(23, 31), 7.5, fill);
      canvas.drawCircle(const Offset(41, 31), 7.5, fill);
      fill.color = LifeTrackColors.ink;
      canvas.drawCircle(const Offset(24.2, 32), 3.6, fill);
      canvas.drawCircle(const Offset(39.8, 32), 3.6, fill);
      fill.color = Colors.white;
      canvas.drawCircle(const Offset(25.4, 30.6), 1.3, fill);
      canvas.drawCircle(const Offset(41, 30.6), 1.3, fill);
    }

    // Beak
    fill.color = _orange;
    canvas.drawPath(
      Path()
        ..moveTo(28.5, 37)
        ..lineTo(35.5, 37)
        ..lineTo(32, 42.5)
        ..close(),
      fill,
    );

    // Blush
    fill.color = LifeTrackColors.coral.withValues(alpha: 0.35);
    canvas.drawCircle(const Offset(14.5, 40), 4, fill);
    canvas.drawCircle(const Offset(49.5, 40), 4, fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.accent != accent || old.accentDeep != accentDeep;
}

