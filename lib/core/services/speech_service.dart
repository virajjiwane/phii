// lib/core/services/speech_service.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:logging/logging.dart';

/// Service that handles speech recognition and command processing
/// for the Phii alarm app
class SpeechService {
  static final _log = Logger('SpeechService');
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  // Callbacks for UI updates
  Function(String text)? onSpeechResult;
  Function(bool isListening)? onListeningStateChanged;
  Function(SpeechCommand command, Map<String, dynamic> params)?
      onCommandDetected;

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
            _processCommand(text);
          }
        },
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
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

  /// Process the recognized speech into commands
  void _processCommand(String text) {
    final cmd = text.toLowerCase().trim();
    _log.info('Processing command: $cmd');

    // Create new alarm
    if (_matchCommand(cmd, ['create', 'alarm'], ['new', 'set', 'add'])) {
      final time = _extractTime(cmd);
      onCommandDetected?.call(SpeechCommand.createAlarm, {'time': time});
      return;
    }

    // Create alarm in specific time
    if (_matchCommand(cmd, ['alarm', 'in'], ['set', 'create'])) {
      final duration = _extractDuration(cmd);
      if (duration != null) {
        onCommandDetected
            ?.call(SpeechCommand.createAlarmIn, {'duration': duration});
        return;
      }
    }

    // Stop all alarms
    if (_matchCommand(cmd, ['stop', 'all'], ['cancel', 'delete', 'remove'])) {
      onCommandDetected?.call(SpeechCommand.stopAll, {});
      return;
    }

    // Show alarms
    if (_matchCommand(cmd, ['show', 'alarm'], ['list', 'display', 'view'])) {
      onCommandDetected?.call(SpeechCommand.showAlarms, {});
      return;
    }

    // Create profile
    if (_matchCommand(cmd, ['create', 'profile'], ['new', 'add', 'make'])) {
      final name = _extractProfileName(cmd);
      onCommandDetected?.call(SpeechCommand.createProfile, {'name': name});
      return;
    }

    // Ring now
    if (_matchCommand(cmd, ['ring', 'now'], ['alarm', 'test', 'immediate'])) {
      onCommandDetected?.call(SpeechCommand.ringNow, {});
      return;
    }

    // Go to settings
    if (_matchCommand(cmd, ['open', 'settings'], ['show', 'go to'])) {
      onCommandDetected?.call(SpeechCommand.openSettings, {});
      return;
    }

    // Go to home
    if (_matchCommand(cmd, ['go', 'home'], ['back', 'return'])) {
      onCommandDetected?.call(SpeechCommand.goHome, {});
      return;
    }

    // Help command
    if (_matchCommand(cmd, ['help'], ['commands', 'what can you do'])) {
      onCommandDetected?.call(SpeechCommand.showHelp, {});
      return;
    }

    // No command matched
    _log.warning('No command matched for: $cmd');
    onCommandDetected?.call(SpeechCommand.unknown, {'text': text});
  }

  /// Helper to match command patterns
  bool _matchCommand(String cmd, List<String> required,
      [List<String> optional = const []]) {
    // All required keywords must be present
    for (final keyword in required) {
      if (!cmd.contains(keyword)) {
        return false;
      }
    }
    return true;
  }

  /// Extract time from command (e.g., "set alarm for 7:30")
  TimeOfDay? _extractTime(String cmd) {
    // Simple pattern matching for times like "7:30", "730", "seven thirty"
    final timePattern = RegExp(r'(\d{1,2}):?(\d{2})');
    final match = timePattern.firstMatch(cmd);

    if (match != null) {
      final hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '');

      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    // Check for "AM" or "PM"
    final amPmPattern = RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false);
    final amPmMatch = amPmPattern.firstMatch(cmd);

    if (amPmMatch != null) {
      var hour = int.tryParse(amPmMatch.group(1) ?? '');
      final amPm = amPmMatch.group(2)?.toLowerCase();

      if (hour != null && amPm != null) {
        if (amPm == 'pm' && hour < 12) hour += 12;
        if (amPm == 'am' && hour == 12) hour = 0;

        if (hour >= 0 && hour < 24) {
          return TimeOfDay(hour: hour, minute: 0);
        }
      }
    }

    return null;
  }

  /// Extract duration from command (e.g., "in 5 minutes", "in 2 hours")
  Duration? _extractDuration(String cmd) {
    // Match patterns like "5 minutes", "2 hours", "30 seconds"
    final minutePattern = RegExp(r'(\d+)\s*(?:minute|min)');
    final hourPattern = RegExp(r'(\d+)\s*(?:hour|hr)');

    final minuteMatch = minutePattern.firstMatch(cmd);
    final hourMatch = hourPattern.firstMatch(cmd);

    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null) {
        return Duration(minutes: minutes);
      }
    }

    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '');
      if (hours != null) {
        return Duration(hours: hours);
      }
    }

    return null;
  }

  /// Extract profile name from command
  String? _extractProfileName(String cmd) {
    // Try to extract name after "called" or "named"
    final patterns = [
      RegExp(r'called\s+(.+)$'),
      RegExp(r'named\s+(.+)$'),
      RegExp(r'name\s+(.+)$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cmd);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
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

/// Enum of supported voice commands
enum SpeechCommand {
  createAlarm,
  createAlarmIn,
  stopAll,
  showAlarms,
  createProfile,
  ringNow,
  openSettings,
  goHome,
  showHelp,
  unknown,
}

/// Extension to get user-friendly command descriptions
extension SpeechCommandExtension on SpeechCommand {
  String get description {
    switch (this) {
      case SpeechCommand.createAlarm:
        return 'Create a new alarm';
      case SpeechCommand.createAlarmIn:
        return 'Create alarm in X minutes/hours';
      case SpeechCommand.stopAll:
        return 'Stop all alarms';
      case SpeechCommand.showAlarms:
        return 'Show all alarms';
      case SpeechCommand.createProfile:
        return 'Create a new profile';
      case SpeechCommand.ringNow:
        return 'Ring alarm immediately';
      case SpeechCommand.openSettings:
        return 'Open settings';
      case SpeechCommand.goHome:
        return 'Go to home screen';
      case SpeechCommand.showHelp:
        return 'Show voice commands help';
      case SpeechCommand.unknown:
        return 'Unknown command';
    }
  }

  String get example {
    switch (this) {
      case SpeechCommand.createAlarm:
        return '"Create alarm for 7:30 AM"';
      case SpeechCommand.createAlarmIn:
        return '"Set alarm in 30 minutes"';
      case SpeechCommand.stopAll:
        return '"Stop all alarms"';
      case SpeechCommand.showAlarms:
        return '"Show my alarms"';
      case SpeechCommand.createProfile:
        return '"Create profile called Morning"';
      case SpeechCommand.ringNow:
        return '"Ring now"';
      case SpeechCommand.openSettings:
        return '"Open settings"';
      case SpeechCommand.goHome:
        return '"Go home"';
      case SpeechCommand.showHelp:
        return '"Help" or "What can you do"';
      case SpeechCommand.unknown:
        return '';
    }
  }
}
