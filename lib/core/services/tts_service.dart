import 'package:flutter_tts/flutter_tts.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:async';

class TTSService {
  static final _log = Logger('TTSService');
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  Future<bool> initializeTTS() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _setAwaitOptions();
      if (isAndroid) {
        _getDefaultEngine();
        _getDefaultVoice();
      }
      _log.info('Text-to-Speech initialized successfully');
      _isInitialized = true;
    } catch (e) {
      _log.severe('Failed to initialize Text-to-Speech: $e');
    }
    return _isInitialized;
  }

  Future<dynamic> _getLanguages() async => await _flutterTts.getLanguages;

  Future<dynamic> _getEngines() async => await _flutterTts.getEngines;

  Future<void> _getDefaultEngine() async {
    var engine = await _flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await _flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future<void> _setAwaitOptions() async {
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    try {
      _log.info('Speaking text: $text');
      if (!_isInitialized) {
        _log.warning('TTS not initialized. Initializing now.');
        await initializeTTS();
      }
      if (null == text || text.isEmpty) {
        _log.warning('No text provided to speak.');
        return;
      }
      await _flutterTts.speak(text);
    } catch (e) {
      _log.severe('Error during speaking: $e');
    }
  }

  Future<void> stop() async {
    try {
      _log.info('Stopping speech');
      await _flutterTts.stop();
    } catch (e) {
      _log.severe('Error stopping speech: $e');
    }
  }
}
