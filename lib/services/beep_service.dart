import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../utils/app_logger.dart';

/// Plays short programmatic beep tones using flutter_soloud's waveform
/// synthesis — no audio assets required.
///
/// Two distinct cues are provided:
///   • [playWarningBeep]  — single mid-pitch tone (~880 Hz)  — "30 s left"
///   • [playUrgentBeep]   — three rapid high-pitch tones (~1200 Hz) — "10 s left"
class BeepService {
  static final BeepService _instance = BeepService._();
  BeepService._();
  static BeepService get instance => _instance;

  /// Duration of a single beep pulse.
  static const _pulseDuration = Duration(milliseconds: 180);

  /// Gap between pulses in the urgent triple-beep.
  static const _pulseGap = Duration(milliseconds: 100);

  // Lazily-loaded waveform sources so we only hit SoLoud once per session.
  AudioSource? _warnSource;
  AudioSource? _urgentSource;
  bool _isLoaded = false;

  /// Pre-load both waveform sources. Call this when the rest phase starts
  /// so the first beep is instant.
  Future<void> preload() async {
    if (_isLoaded) return;
    try {
      // Mid-pitch sine for the 30-second warning.
      _warnSource = await SoLoud.instance.loadWaveform(
        WaveForm.sin,
        false,
        1.0,
        0.0,
      );
      SoLoud.instance.setWaveformFreq(_warnSource!, 880.0);

      // Higher-pitch sine for the 10-second urgent cue.
      _urgentSource = await SoLoud.instance.loadWaveform(
        WaveForm.sin,
        false,
        1.0,
        0.0,
      );
      SoLoud.instance.setWaveformFreq(_urgentSource!, 1200.0);

      _isLoaded = true;
      AppLogger.info('[BeepService] waveforms preloaded');
    } catch (e) {
      AppLogger.error('[BeepService] preload error', e);
    }
  }

  /// Single mid-pitch beep — played when ~30 s of rest remain.
  Future<void> playWarningBeep() async {
    await _playPulse(_warnSource);
  }

  /// Three rapid high-pitched beeps — played when ~10 s of rest remain.
  Future<void> playUrgentBeep() async {
    for (var i = 0; i < 3; i++) {
      await _playPulse(_urgentSource);
      if (i < 2) await Future.delayed(_pulseGap);
    }
  }

  Future<void> _playPulse(AudioSource? source) async {
    if (source == null) return;
    try {
      final handle = await SoLoud.instance.play(source);
      await Future.delayed(_pulseDuration);
      try {
        SoLoud.instance.stop(handle);
      } catch (_) {}
    } catch (e) {
      AppLogger.error('[BeepService] play error', e);
    }
  }

  /// Release waveform sources. Call this when the workout session ends.
  Future<void> dispose() async {
    _isLoaded = false;
    for (final src in [_warnSource, _urgentSource]) {
      if (src != null) {
        try {
          await SoLoud.instance.disposeSource(src);
        } catch (_) {}
      }
    }
    _warnSource = null;
    _urgentSource = null;
    AppLogger.info('[BeepService] disposed');
  }
}
