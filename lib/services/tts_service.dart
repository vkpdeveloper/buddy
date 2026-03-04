import 'tts_cache.dart';

/// Thin facade kept for backward-compatibility.
/// All logic is in [TtsCache].
class TtsService {
  static final TtsService _instance = TtsService._();
  TtsService._();
  static TtsService get instance => _instance;

  Future<void> speak(String text) => TtsCache.instance.play(text);
  void stop() => TtsCache.instance.stop();
  bool get isPlaying => TtsCache.instance.isPlaying;
}
