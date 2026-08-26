import 'dart:async';

/// Countdown logic for Screen "JAVA PRACTICE 24:37" (Phase 4 §9).
/// Pure state/logic, no UI — a screen widget wraps this and rebuilds on
/// each tick. Defaults match the doc's "25-minute focus / 5-minute break".
class FocusTimerService {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isPaused = false;

  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _timer != null && !_isPaused;
  bool get isPaused => _isPaused;

  /// Starts (or restarts) a countdown. [onTick] fires every second with
  /// the remaining seconds; [onComplete] fires once when it hits zero.
  void start({
    required int durationMinutes,
    required void Function(int remainingSeconds) onTick,
    required void Function() onComplete,
  }) {
    _timer?.cancel();
    _remainingSeconds = durationMinutes * 60;
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;
      _remainingSeconds--;
      onTick(_remainingSeconds);
      if (_remainingSeconds <= 0) {
        onComplete();
        end();
      }
    });
  }

  void pause() => _isPaused = true;

  void resume() => _isPaused = false;

  void end() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 0;
    _isPaused = false;
  }
}