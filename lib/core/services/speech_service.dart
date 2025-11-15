// lib/core/services/speech_service.dart
import 'package:flutter/material.dart';
import 'package:phii/core/services/gemini_service.dart';
import 'package:phii/models/speech_command.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:logging/logging.dart';
import 'package:phii/core/services/tts_service.dart';

/// Service that handles speech recognition and command processing
/// for the Phii alarm app
class SpeechService {
  static final _log = Logger('SpeechService');
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiSpeechService _geminiService = GeminiSpeechService();
  final TTSService _ttsService = TTSService();

  bool _isInitialized = false;
  bool _isListening = false;

  // Callbacks for UI updates
  Function(String text)? onSpeechResult;
  Function(bool isListening)? onListeningStateChanged;
  Function(ParsedSpeechCommand command)?
      onCommandDetected;
Function(String text)? onCommandFeedback;

  /// Initialize the speech recognition engine
  Future<bool> initialize(BuildContext context) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          _log.info('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStateChanged?.call(false);
          }
        },
        onError: (error) {
          _log.severe('Speech error: $error');
          _isListening = false;
          onListeningStateChanged?.call(false);
        },
      );

      _log.info('Speech recognition initialized: $_isInitialized');

      if (_geminiService.initialize()) {
        _log.info('Gemini Service initialized');
      } else {
        _log.warning('Gemini Service failed to initialize');
      }      

      if (await _ttsService.initializeTTS()) {
        _log.info('TTS Service initialized');
      } else {
        _log.warning('TTS Service failed to initialize');
      }
    } catch (e) {
      _log.severe('Failed to initialize speech: $e');
    }
    if (!_isInitialized) {
      // Show error message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Speech Not Available'),
          content: Text('Your device does not support speech recognition'),
        ),
      );
    }
    return _isInitialized;
  }

  /// Start listening for voice commands
  Future<void> startListening(BuildContext context) async {
    if (!_isInitialized) {
      final initialized = await initialize(context);
      if (!initialized) {
        _log.warning('Cannot start listening - initialization failed');
        return;
      }
    }

    if (_isListening) {
      _log.warning('Already listening');
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          _log.info('Recognized: $text (final: ${result.finalResult})');

          // Update UI with recognized text
          onSpeechResult?.call(text);

          // Process command when speech is final
          if (result.finalResult) {
            _geminiService.parseSpeechCommand(text).then((command) {
              onCommandDetected?.call(command);
              _geminiService.getCommandFeedback(command).then((feedback) {
                // Optionally, provide feedback to the user
                _log.info('Command feedback: $feedback');
                onCommandFeedback?.call(feedback);
                _ttsService.speak(feedback);
              });
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.confirmation,cancelOnError: true,partialResults: true),
      );

      _isListening = true;
      onListeningStateChanged?.call(true);
      _log.info('Started listening');
    } catch (e) {
      _log.severe('Failed to start listening: $e');
      _isListening = false;
      onListeningStateChanged?.call(false);
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      onListeningStateChanged?.call(false);
      _log.info('Stopped listening');
    } catch (e) {
      _log.severe('Failed to stop listening: $e');
    }
  }
  

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _speech.cancel();
  }
}