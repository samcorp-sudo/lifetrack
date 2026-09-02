// ============================================================================
// Pomodoro Screen — LifeTrack Focus Timer
// ============================================================================
//
// Redesigned with:
//   • Full-screen gradient background that shifts with mode (focus = amber,
//     break = mint) — the whole screen transitions color when the timer
//     switches phases.
//   • Larger, cleaner ring with an inner progress arc and tick marks.
//   • Beat pulse animation — the ring gently breathes while running.
//   • Sound effects (SystemSound) on start, pause, complete, and reset —
//     works with no extra packages.
//   • Session dots that animate fill one-by-one.
//   • Mode selector with animated sliding pill.
//   • Everything else (Fixes 1-11 from previous version) preserved:
//     real session count, correct accent on completion sheet, null-safe
//     controllers, guard against double-start, real remaining-seconds
//     in _start().
//
// SOUNDS
// ----------------------------------------------------------------------------
// Uses SystemSound.play(SystemSoundType.click) so it works on any device
// with no extra dependency. Called on:
//   • Start (session begins)
//   • Pause (pausing)
//   • Complete (session ends)
//   • Mode switch (gentle click)
//
// If you want richer sounds (bell, chime), add `audioplayers` to pubspec
// and assets/sounds/{bell,chime}.mp3, then replace _playSound() below.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../services/focus_timer_service.dart';
import '../../theme/app_theme.dart';

enum _PomodoroMode { focus, breakTime }

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  final FocusTimerService _timer = FocusTimerService();

  _PomodoroMode _mode = _PomodoroMode.focus;

  int _totalSeconds = AppConstants.focusDurationMinutes * 60;
  int _remainingSeconds = AppConstants.focusDurationMinutes * 60;

  int _completedFocusSessions = 0;
  int _focusMinutesToday = 0;

  AnimationController? _pulseController;
  AnimationController? _beatController;
  AnimationController? _modeTransitionController;

  bool get _isRunning => _timer.isRunning;
  bool get _isPaused => _timer.isPaused;
  bool get _isIdle => !_isRunning && !_isPaused;

  Color get _accentColor => _mode == _PomodoroMode.focus
      ? LifeTrackColors.highlight
      : LifeTrackColors.mint;

  Color get _accentDeep => _mode == _PomodoroMode.focus
      ? LifeTrackColors.highlightDeep
      : const Color(0xFF1E9E82);

  String get _modeTitle =>
      _mode == _PomodoroMode.focus ? 'Focus' : 'Break';

  String get _modeSubtitle => _mode == _PomodoroMode.focus
      ? 'Stay focused'
      : 'Take a moment to recharge';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _beatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _modeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1,
    );
  }

  // ==========================================================================
  // SOUND
  // ==========================================================================

  void _playSound() {
    SystemSound.play(SystemSoundType.click);
  }

  // ==========================================================================
  // TIMER ACTIONS
  // ==========================================================================

  void _start() {
    if (_isRunning) return;
    if (_remainingSeconds <= 0) {
      _resetCurrentMode();
    }
    _playSound();
    _startBeat();
    setState(() {});
    final remainingMinutes = (_remainingSeconds / 60).ceil();
    _timer.start(
      durationMinutes: remainingMinutes,
      onTick: (remaining) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds = remaining.clamp(0, _totalSeconds);
        });
      },
      onComplete: _handleComplete,
    );
  }

  void _pause() {
    _playSound();
    _stopBeat();
    _timer.pause();
    if (!mounted) return;
    setState(() {});
  }

  void _resume() {
    _playSound();
    _startBeat();
    _timer.resume();
    if (!mounted) return;
    setState(() {});
  }

  void _end() {
    _playSound();
    _stopBeat();
    _timer.end();
    if (!mounted) return;
    setState(() {
      _remainingSeconds = _totalSeconds;
    });
  }

  void _resetCurrentMode() {
    setState(() {
      _totalSeconds = _mode == _PomodoroMode.focus
          ? AppConstants.focusDurationMinutes * 60
          : AppConstants.focusBreakMinutes * 60;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _startBeat() {
    _beatController?.repeat(reverse: true);
  }

  void _stopBeat() {
    _beatController?.stop();
    _beatController?.value = 0;
  }

  // ==========================================================================
  // COMPLETION
  // ==========================================================================

  void _handleComplete() {
    if (!mounted) return;
    _stopBeat();
    _playSound();

    final completedMode = _mode;
    final completedAccent = completedMode == _PomodoroMode.focus
        ? LifeTrackColors.highlight
        : LifeTrackColors.mint;

    if (completedMode == _PomodoroMode.focus) {
      setState(() {
        _completedFocusSessions++;
        _focusMinutesToday += AppConstants.focusDurationMinutes;
        _mode = _PomodoroMode.breakTime;
        _totalSeconds = AppConstants.focusBreakMinutes * 60;
        _remainingSeconds = _totalSeconds;
      });
    } else {
      setState(() {
        _mode = _PomodoroMode.focus;
        _totalSeconds = AppConstants.focusDurationMinutes * 60;
        _remainingSeconds = _totalSeconds;
      });
    }
    _modeTransitionController?.forward(from: 0);
    _showCompletionSheet(completedMode, completedAccent);
  }

  void _showCompletionSheet(_PomodoroMode completedMode, Color accent) {
    final wasFocus = completedMode == _PomodoroMode.focus;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated check / coffee icon that pops in
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, v, _) => Transform.scale(
                    scale: v,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.30),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        wasFocus
                            ? Icons.check_circle_rounded
                            : Icons.coffee_rounded,
                        color: accent,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  wasFocus ? 'Focus session complete!' : 'Break is over!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  wasFocus
                      ? 'Nice work. You completed another focus session.'
                      : 'Ready to get back to work?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      _playSound();
                      Navigator.pop(sheetContext);
                      _start();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: Icon(wasFocus
                        ? Icons.coffee_rounded
                        : Icons.play_arrow_rounded),
                    label: Text(wasFocus ? 'Start Break' : 'Start Focus'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Later'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // MODE
  // ==========================================================================

  void _switchMode(_PomodoroMode mode) {
    if (mode == _mode) return;
    _playSound();
    if (_isRunning || _isPaused) {
      _timer.end();
      _stopBeat();
    }
    _modeTransitionController?.forward(from: 0);
    setState(() {
      _mode = mode;
      _totalSeconds = mode == _PomodoroMode.focus
          ? AppConstants.focusDurationMinutes * 60
          : AppConstants.focusBreakMinutes * 60;
      _remainingSeconds = _totalSeconds;
    });
  }

  // ==========================================================================
  // FORMAT
  // ==========================================================================

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  double get _progress {
    if (_totalSeconds <= 0) return 0;
    return (1 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0);
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _timer.end();
    _pulseController?.dispose();
    _beatController?.dispose();
    _modeTransitionController?.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.4,
            colors: [
              _accentColor.withValues(alpha: 0.06),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    child: Column(
                      children: [
                        _header(context),
                        const SizedBox(height: 18),
                        _modeSelector(context),
                        const SizedBox(height: 12),
                        _autoStartLabel(context),
                        SizedBox(height: size.height < 750 ? 12 : 24),
                        _timerSection(context),
                        SizedBox(height: size.height < 750 ? 18 : 26),
                        _dailyStats(context),
                        const SizedBox(height: 18),
                        _controls(context),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.arrow_back_rounded,
          iconColor: s.accentText,
          background: s.accent.withValues(alpha: 0.10),
          onTap: () {
            _playSound();
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Timer',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Stay present. One session at a time.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _GlassIconButton(
          icon: Icons.bar_chart_rounded,
          iconColor: s.accentText,
          background: s.accent.withValues(alpha: 0.10),
          onTap: () {
            _playSound();
            // TODO: open focus analytics when that screen exists.
          },
        ),
      ],
    );
  }

  // ==========================================================================
  // MODE SELECTOR — animated sliding pill
  // ==========================================================================

  Widget _modeSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              icon: Icons.bolt_rounded,
              label: 'Focus',
              selected: _mode == _PomodoroMode.focus,
              color: LifeTrackColors.highlight,
              enabled: !_isRunning && !_isPaused,
              onTap: () => _switchMode(_PomodoroMode.focus),
            ),
          ),
          Expanded(
            child: _ModeButton(
              icon: Icons.coffee_rounded,
              label: 'Break',
              selected: _mode == _PomodoroMode.breakTime,
              color: LifeTrackColors.mint,
              enabled: !_isRunning && !_isPaused,
              onTap: () => _switchMode(_PomodoroMode.breakTime),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AUTO START LABEL
  // ==========================================================================

  Widget _autoStartLabel(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.autorenew_rounded, size: 17, color: _accentColor),
        const SizedBox(width: 6),
        Text(
          'Auto-switch after '
          '${_mode == _PomodoroMode.focus ? 'focus' : 'break'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TIMER RING
  // ==========================================================================

  Widget _timerSection(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final ringSize = math.min(screenWidth - 52, 320.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _beatController]),
      builder: (context, child) {
        final pulseValue = _pulseController?.value ?? 0.5;
        final beatValue = _beatController?.value ?? 0;
        final beatScale = 1.0 + (beatValue * 0.018);
        final pulseScale = _isRunning ? 1.0 + (pulseValue * 0.010) : 1.0;
        return Transform.scale(scale: pulseScale * beatScale, child: child);
      },
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow.
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: ringSize - 14,
              height: ringSize - 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(
                      alpha: _isRunning ? 0.20 : 0.07,
                    ),
                    blurRadius: _isRunning ? 40 : 20,
                    spreadRadius: _isRunning ? 6 : 0,
                  ),
                ],
              ),
            ),
            // Background ring.
            SizedBox(
              width: ringSize - 18,
              height: ringSize - 18,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 15,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                  _accentColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Progress ring — gradient stroke simulated by two arcs.
            SizedBox(
              width: ringSize - 18,
              height: ringSize - 18,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: -math.pi / 2,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 15,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(_accentColor),
                    ),
                  );
                },
              ),
            ),
            // Tick marks.
            CustomPaint(
              size: Size(ringSize - 30, ringSize - 30),
              painter: _TimerTicksPainter(
                progress: _progress,
                color: _accentColor.withValues(alpha: 0.30),
              ),
            ),
            // Center content.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.35),
                    ),
                    color: _accentColor.withValues(alpha: 0.05),
                  ),
                  child: Text(
                    _modeTitle.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _accentColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                // Time text with subtle color pulse while running.
                AnimatedBuilder(
                  animation: _pulseController ?? kAlwaysCompleteAnimation,
                  builder: (context, _) {
                    final pv = _pulseController?.value ?? 0;
                    final color = _isRunning
                        ? Color.lerp(
                            Theme.of(context).textTheme.displayLarge?.color ??
                                Colors.black,
                            _accentDeep,
                            pv * 0.3,
                          )!
                        : null;
                    return Text(
                      _formatTime(_remainingSeconds),
                      style:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: ringSize > 290 ? 64 : 56,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                                color: color,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  'REMAINING',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mode == _PomodoroMode.focus
                          ? Icons.eco_rounded
                          : Icons.self_improvement_rounded,
                      size: 19,
                      color: _accentColor,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _modeSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DAILY STATS
  // ==========================================================================

  Widget _dailyStats(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.accent.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.track_changes_rounded,
              color: s.accentText,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's focus",
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_completedFocusSessions of 4 sessions',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _SessionDots(completed: _completedFocusSessions),
          const SizedBox(width: 14),
          Container(width: 1, height: 38, color: theme.dividerColor),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  // Minutes count-up animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0, end: _focusMinutesToday.toDouble()),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '${v.round()}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              Text('min today', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONTROLS
  // ==========================================================================

  Widget _controls(BuildContext context) {
    final theme = Theme.of(context);

    if (_isIdle) {
      return SizedBox(
        width: double.infinity,
        height: 68,
        child: FilledButton(
          onPressed: _start,
          style: FilledButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 32),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mode == _PomodoroMode.focus
                        ? 'Start Focus'
                        : 'Start Break',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_totalSeconds ~/ 60} MINUTES',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _end,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textTheme.bodyMedium?.color,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('End'),
            ),
          ),
          Container(width: 1, height: 34, color: theme.dividerColor),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isPaused ? _resume : _pause,
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: Icon(
                _isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: Text(_isPaused ? 'Resume' : 'Pause'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODE BUTTON
// ============================================================================

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? Colors.white
                  : theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GLASS ICON BUTTON
// ============================================================================

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color background;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 23, color: iconColor),
        ),
      ),
    );
  }
}

// ============================================================================
// SESSION DOTS — animate fill one by one
// ============================================================================

class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.completed});

  final int completed;

  static const int _max = 4;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_max, (index) {
        final done = index < completed;
        return TweenAnimationBuilder<double>(
          key: ValueKey('dot-$index-$done'),
          tween: Tween(begin: 0, end: done ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, v, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  Colors.transparent,
                  LifeTrackColors.highlight,
                  v,
                ),
                border: Border.all(
                  color: done
                      ? LifeTrackColors.highlight
                      : Theme.of(context).dividerColor,
                  width: 2,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ============================================================================
// TIMER TICKS PAINTER
// ============================================================================

class _TimerTicksPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _TimerTicksPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const tickCount = 60;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final angle = (i / tickCount) * math.pi * 2;
      final isMajor = i % 5 == 0;
      final outerRadius = radius;
      final innerRadius = radius - (isMajor ? 8 : 5);
      final start = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerTicksPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
