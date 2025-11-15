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

extension SpeechCommandExtension on SpeechCommand {
  String get description {
    switch (this) {
      case SpeechCommand.createAlarm:
        return 'Set an alarm at a specific time';
      case SpeechCommand.createAlarmIn:
        return 'Set an alarm after a duration from now';
      case SpeechCommand.stopAll:
        return 'Stop and remove all active alarms';
      case SpeechCommand.showAlarms:
        return 'Display all configured alarms';
      case SpeechCommand.createProfile:
        return 'Create a new alarm profile/group';
      case SpeechCommand.ringNow:
        return 'Trigger an alarm immediately for testing';
      case SpeechCommand.openSettings:
        return 'Navigate to app settings';
      case SpeechCommand.goHome:
        return 'Return to the home screen';
      case SpeechCommand.showHelp:
        return 'Show available voice commands';
      case SpeechCommand.unknown:
        return 'Command not recognized';
    }
  }

  List<String> get examples {
    switch (this) {
      case SpeechCommand.createAlarm:
        return [
          'Set alarm for 7 AM',
          'Wake me up at 8:30',
          'Create alarm for 6:45 PM',
          'Set an alarm at noon',
          'Wake me at 5 in the morning',
        ];
      case SpeechCommand.createAlarmIn:
        return [
          'Set alarm in 30 minutes',
          'Wake me up in 2 hours',
          'Alarm in 45 minutes',
          'Set alarm in 1 hour and 15 minutes',
          'Wake me in an hour',
        ];
      case SpeechCommand.stopAll:
        return [
          'Stop all alarms',
          'Cancel all alarms',
          'Turn off all alarms',
          'Disable all alarms',
          'Remove all my alarms',
        ];
      case SpeechCommand.showAlarms:
        return [
          'Show my alarms',
          'List all alarms',
          'What alarms do I have',
          'Display my alarms',
          'Show all active alarms',
        ];
      case SpeechCommand.createProfile:
        return [
          'Create profile work',
          'New profile weekday',
          'Make a profile called morning',
          'Create alarm group weekend',
          'New profile gym',
        ];
      case SpeechCommand.ringNow:
        return [
          'Ring now',
          'Test alarm',
          'Ring the alarm',
          'Trigger alarm now',
          'Test my alarm sound',
        ];
      case SpeechCommand.openSettings:
        return [
          'Open settings',
          'Go to settings',
          'Show settings',
          'Settings page',
          'Open preferences',
        ];
      case SpeechCommand.goHome:
        return [
          'Go home',
          'Back to home',
          'Return to main screen',
          'Go to home screen',
          'Take me home',
        ];
      case SpeechCommand.showHelp:
        return [
          'Help',
          'What can you do',
          'Show help',
          'Voice commands',
          'How do I use this',
        ];
      case SpeechCommand.unknown:
        return [
          'Sorry, I didn\'t understand that',
        ];
    }
  }

  String get icon {
    switch (this) {
      case SpeechCommand.createAlarm:
        return '⏰';
      case SpeechCommand.createAlarmIn:
        return '⏱️';
      case SpeechCommand.stopAll:
        return '🛑';
      case SpeechCommand.showAlarms:
        return '📋';
      case SpeechCommand.createProfile:
        return '📁';
      case SpeechCommand.ringNow:
        return '🔔';
      case SpeechCommand.openSettings:
        return '⚙️';
      case SpeechCommand.goHome:
        return '🏠';
      case SpeechCommand.showHelp:
        return '❓';
      case SpeechCommand.unknown:
        return '❌';
    }
  }

  String get commandKey {
    switch (this) {
      case SpeechCommand.createAlarm:
        return 'create_alarm';
      case SpeechCommand.createAlarmIn:
        return 'create_alarm_in';
      case SpeechCommand.stopAll:
        return 'stop_all';
      case SpeechCommand.showAlarms:
        return 'show_alarms';
      case SpeechCommand.createProfile:
        return 'create_profile';
      case SpeechCommand.ringNow:
        return 'ring_now';
      case SpeechCommand.openSettings:
        return 'open_settings';
      case SpeechCommand.goHome:
        return 'go_home';
      case SpeechCommand.showHelp:
        return 'show_help';
      case SpeechCommand.unknown:
        return 'unknown';
    }
  }
}

class ParsedSpeechCommand {
  final SpeechCommand command;
  final Map<String, dynamic> parameters;
  final String originalText;
  final double confidence;

  ParsedSpeechCommand({
    required this.command,
    required this.parameters,
    required this.originalText,
    this.confidence = 1.0,
  });

  factory ParsedSpeechCommand.fromJson(Map<String, dynamic> json) {
    return ParsedSpeechCommand(
      command: _parseCommand(json['command'] as String?),
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      originalText: json['originalText'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static SpeechCommand _parseCommand(String? commandStr) {
    if (commandStr == null) return SpeechCommand.unknown;
    
    final normalizedCommand = commandStr.toLowerCase().replaceAll(' ', '_');
    
    for (final command in SpeechCommand.values) {
      if (command.commandKey == normalizedCommand) {
        return command;
      }
    }
    
    return SpeechCommand.unknown;
  }
  
  /// Get command by its key string
  static SpeechCommand fromKey(String key) {
    for (final command in SpeechCommand.values) {
      if (command.commandKey == key) {
        return command;
      }
    }
    return SpeechCommand.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'command': command.toString().split('.').last,
      'parameters': parameters,
      'originalText': originalText,
      'confidence': confidence,
    };
  }
}