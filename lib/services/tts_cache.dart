import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'tts_api_service.dart';
import '../utils/app_logger.dart';

/// Pre-fetches and caches TTS audio clips keyed by text.
///
/// Usage:
///   1. Call [prefetch] with all texts in playback order.
///   2. Call [play] to play a clip; instant if pre-fetched, falls back to
///      a live fetch otherwise.
///   3. Call [dispose] when the session ends to release memory.
class TtsCache {
  static final TtsCache _instance = TtsCache._();
  TtsCache._();
  static TtsCache get instance => _instance;

  // Max clips to keep fetched ahead of the current position.
  static const int _lookAhead = 2;

  // Ordered list of all texts registered via prefetch().
  final List<String> _queue = [];
  // key → loaded AudioSource (ready to play)
  final Map<String, AudioSource> _loaded = {};
  // key → in-flight fetch future (deduplicates concurrent requests)
  final Map<String, Future<AudioSource?>> _inflight = {};
  // Index of the most recently played (or being played) clip in _queue.
  int _headIndex = -1;
  // Whether the background drip-feed loop is running.
  bool _pumping = false;

  SoundHandle? _currentHandle;

  /// Register [texts] in playback order and start fetching up to
  /// [_lookAhead] clips from the front. Safe to call multiple times;
  /// already-cached/queued entries are skipped.
  void prefetch(List<String> texts) {
    for (final text in texts) {
      if (!_queue.contains(text)) {
        _queue.add(text);
      }
    }
    _pump();
  }

  /// Fetch at most [_lookAhead] clips ahead of [_headIndex], one at a time.
  void _pump() {
    if (_pumping) return;
    _pumping = true;
    _pumpNext();
  }

  void _pumpNext() {
    // Find the next uncached clip within the look-ahead window.
    final limit = (_headIndex + 1 + _lookAhead).clamp(0, _queue.length);
    String? next;
    for (var i = _headIndex + 1; i < limit; i++) {
      final text = _queue[i];
      if (!_loaded.containsKey(text) && !_inflight.containsKey(text)) {
        next = text;
        break;
      }
    }

    if (next == null) {
      _pumping = false;
      return;
    }

    _fetchAndLoad(next).then((_) => _pumpNext());
  }

  /// Returns a future that completes when [text] is loaded (or fails).
  /// Idempotent — repeated calls for the same text share the same future.
  Future<AudioSource?> _ensureLoaded(String text) {
    if (_loaded.containsKey(text)) {
      return Future.value(_loaded[text]);
    }
    if (_inflight.containsKey(text)) {
      return _inflight[text]!;
    }
    final future = _fetchAndLoad(text);
    _inflight[text] = future;
    return future;
  }

  Future<AudioSource?> _fetchAndLoad(String text) async {
    try {
      AppLogger.info('[TTSCache] fetch start (len=${text.length})');
      final bytes = await TtsApiService.ttsBytes(text);
      if (bytes.isEmpty) {
        AppLogger.warn('[TTSCache] empty bytes for text (len=${text.length})');
        return null;
      }
      // Use a stable cache key derived from text as the "filename" for loadMem.
      final key = 'tts_${text.hashCode}.mp3';
      final source = await SoLoud.instance.loadMem(key, bytes);
      _loaded[text] = source;
      _inflight.remove(text);
      AppLogger.info('[TTSCache] loaded (len=${text.length}) key=$key');
      return source;
    } catch (e) {
      _inflight.remove(text);
      AppLogger.error('[TTSCache] fetch error (len=${text.length})', e);
      return null;
    }
  }

  /// Play [text], waiting for it to be fetched if not yet ready.
  /// Stops any currently playing clip first.
  /// Returns when playback completes.
  Future<void> play(String text) async {
    stop();

    // Advance the head pointer so _pump() fetches the next look-ahead window.
    final idx = _queue.indexOf(text);
    if (idx != -1) {
      _headIndex = idx;
      _pump();
    }

    // Wait for the cached source (or trigger a fresh fetch if not pre-warmed).
    final source = await _ensureLoaded(text);
    if (source == null) {
      AppLogger.error('[TTSCache] no source for text, skipping playback', null);
      return;
    }

    // Subscribe BEFORE play() to avoid missing the completion event if the
    // clip finishes before the listener is attached (race condition).
    final completion = Completer<void>();
    final sub = source.soundEvents.listen((event) {
      if (event.event == SoundEventType.handleIsNoMoreValid &&
          !completion.isCompleted) {
        AppLogger.info('[TTSCache] handle complete');
        completion.complete();
      }
    });

    final handle = await SoLoud.instance.play(source);
    _currentHandle = handle;
    AppLogger.info('[TTSCache] play handle=$handle');

    await completion.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => AppLogger.warn('[TTSCache] playback timeout'),
    );

    await sub.cancel();
    _currentHandle = null;
  }

  /// Stop current playback immediately.
  void stop() {
    final handle = _currentHandle;
    _currentHandle = null;
    if (handle != null) {
      try {
        SoLoud.instance.stop(handle);
      } catch (_) {}
    }
  }

  /// Whether a clip is currently playing.
  bool get isPlaying => _currentHandle != null;

  /// Whether [text] has been fully fetched and is ready to play instantly.
  bool isReady(String text) => _loaded.containsKey(text);

  /// Starts fetching [texts] concurrently (fire-and-forget, max 2).
  /// Already-cached or in-flight texts are skipped automatically.
  void ensureReady(List<String> texts) {
    for (final text in texts.take(2)) {
      _ensureLoaded(text);
    }
  }

  /// Release all cached [AudioSource] objects and clear state.
  Future<void> dispose() async {
    stop();
    _queue.clear();
    _headIndex = -1;
    _pumping = false;
    for (final source in _loaded.values) {
      try {
        await SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
    _loaded.clear();
    _inflight.clear();
    AppLogger.info('[TTSCache] disposed');
  }
}
