import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:phii/models/speech_command.dart';
import 'package:phii/models/profile.dart';
import 'package:phii/screens/settings_screen.dart';
import 'alarm_service.dart';
import 'profile_service.dart';

/// Service that handles executing speech commands
/// Coordinates between AlarmService and ProfileService
class CommandHandlerService {
  static final _log = Logger('CommandHandlerService');
  
  final AlarmService _alarmService = AlarmService();
  final ProfileService _profileService = ProfileService();

  /// Execute a parsed speech command
  /// Returns a result message describing what happened
  Future<String> executeCommand(ParsedSpeechCommand command, BuildContext context) async {
    _log.info('Executing command: ${command.command.commandKey}');
    
    switch (command.command) {
      case SpeechCommand.createAlarm:
        return await _handleCreateAlarm(command);
      
      case SpeechCommand.createAlarmIn:
        return await _handleCreateAlarmIn(command);
      
      case SpeechCommand.stopAll:
        return await _handleStopAll(command);
      
      case SpeechCommand.createProfile:
        return await _handleCreateProfile(command);
      
      case SpeechCommand.deleteAllProfiles:
        return await _handleDeleteAllProfiles(command);
      
      case SpeechCommand.ringNow:
        return await _handleRingNow(command);
      
      case SpeechCommand.showAlarms:
        return await _handleShowAlarms(command);
      
      case SpeechCommand.openSettings:
        Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
        return 'Settings aren\'t integrated yet.';
      
      case SpeechCommand.goHome:
        // Pop to home screen
        Navigator.popUntil(context, (route) => route.isFirst);
        return 'You are at the Home Screen.';
      
      case SpeechCommand.showHelp:
        showVoiceCommandsHelp(context);
        return 'These are the available voice commands.';
      
      case SpeechCommand.unknown:
        return 'I didn\'t understand that command. Try saying "help" to see available commands.';
    }
  }

  /// Handle creating an alarm at a specific time
  Future<String> _handleCreateAlarm(ParsedSpeechCommand command) async {
    try {
      // Extract time parameters
      final hour = command.parameters['hour'] as int?;
      final minute = command.parameters['minute'] as int?;
      final profileName = command.parameters['profile'] as String?;

      if (hour == null) {
        return 'Please specify what time you want the alarm.';
      }

      // Build the datetime
      final now = DateTime.now();
      var alarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute ?? 0,
      );

      // If time has passed today, set for tomorrow
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }

      // Get or create profile
      Profile? profile;
      if (profileName != null) {
        profile = await _profileService.getOrCreateProfile(profileName);
      } else {
        // Use default profile or create one
        final profiles = _profileService.getAllProfiles();
        if (profiles.isNotEmpty) {
          profile = profiles.first;
        } else {
          profile = await _profileService.createProfile(name: 'Default');
        }
      }

      if (profile == null) {
        return 'Failed to create or find profile.';
      }

      // Create the alarm
      final alarmId = await _alarmService.createAlarmAt(dateTime: alarmTime);
      
      if (alarmId == null) {
        return 'Failed to create alarm.';
      }

      // Add to profile
      await _profileService.addAlarmToProfile(profile.id, alarmId);

      final timeStr = '${hour.toString().padLeft(2, '0')}:${(minute ?? 0).toString().padLeft(2, '0')}';
      return 'Alarm set for $timeStr in profile "${profile.name}".';
    } catch (e) {
      _log.severe('Error handling create alarm: $e');
      return 'Failed to create alarm: $e';
    }
  }

  /// Handle creating an alarm after a duration
  Future<String> _handleCreateAlarmIn(ParsedSpeechCommand command) async {
    try {
      // Extract duration parameters
      final hours = command.parameters['hours'] as int? ?? 0;
      final minutes = command.parameters['minutes'] as int? ?? 0;
      final profileName = command.parameters['profile'] as String?;

      if (hours == 0 && minutes == 0) {
        return 'Please specify how long from now you want the alarm.';
      }

      final duration = Duration(hours: hours, minutes: minutes);

      // Get or create profile
      Profile? profile;
      if (profileName != null) {
        profile = await _profileService.getOrCreateProfile(profileName);
      } else {
        final profiles = _profileService.getAllProfiles();
        if (profiles.isNotEmpty) {
          profile = profiles.first;
        } else {
          profile = await _profileService.createProfile(name: 'Default');
        }
      }

      if (profile == null) {
        return 'Failed to create or find profile.';
      }

      // Create the alarm
      final alarmId = await _alarmService.createAlarmIn(duration: duration);
      
      if (alarmId == null) {
        return 'Failed to create alarm.';
      }

      // Add to profile
      await _profileService.addAlarmToProfile(profile.id, alarmId);

      String durationStr = '';
      if (hours > 0) {
        durationStr += '$hours hour${hours > 1 ? 's' : ''}';
      }
      if (minutes > 0) {
        if (durationStr.isNotEmpty) durationStr += ' and ';
        durationStr += '$minutes minute${minutes > 1 ? 's' : ''}';
      }

      return 'Alarm set for $durationStr from now in profile "${profile.name}".';
    } catch (e) {
      _log.severe('Error handling create alarm in: $e');
      return 'Failed to create alarm: $e';
    }
  }

  /// Handle stopping all alarms
  Future<String> _handleStopAll(ParsedSpeechCommand command) async {
    try {
      final count = await _alarmService.stopAllAlarms();
      
      if (count == 0) {
        return 'No alarms to stop.';
      } else if (count == 1) {
        return 'Stopped 1 alarm.';
      } else {
        return 'Stopped $count alarms.';
      }
    } catch (e) {
      _log.severe('Error handling stop all: $e');
      return 'Failed to stop alarms: $e';
    }
  }

  /// Handle creating a profile
  Future<String> _handleCreateProfile(ParsedSpeechCommand command) async {
    try {
      final profileName = command.parameters['name'] as String?;

      if (profileName == null || profileName.trim().isEmpty) {
        return 'Please specify a name for the profile.';
      }

      // Check if profile already exists
      final existing = _profileService.findProfileByName(profileName);
      if (existing != null) {
        return 'Profile "$profileName" already exists.';
      }

      // Create the profile
      final profile = await _profileService.createProfile(name: profileName);
      
      if (profile == null) {
        return 'Failed to create profile.';
      }

      return 'Created profile "$profileName".';
    } catch (e) {
      _log.severe('Error handling create profile: $e');
      return 'Failed to create profile: $e';
    }
  }

  /// Handle deleting all profiles
  Future<String> _handleDeleteAllProfiles(ParsedSpeechCommand command) async {
    try {
      final profiles = _profileService.getAllProfiles();
      
      if (profiles.isEmpty) {
        return 'No profiles to delete.';
      }

      final count = profiles.length;
      
      // Delete all profiles
      for (final profile in profiles) {
        await _profileService.deleteProfile(profile.id, stopAlarms: true);
      }

      if (count == 1) {
        return 'Deleted 1 profile and all its alarms.';
      } else {
        return 'Deleted $count profiles and all their alarms.';
      }
    } catch (e) {
      _log.severe('Error handling delete all profiles: $e');
      return 'Failed to delete profiles: $e';
    }
  }

  /// Handle ring now command
  Future<String> _handleRingNow(ParsedSpeechCommand command) async {
    try {
      final profileName = command.parameters['profile'] as String?;

      // Get or create profile
      Profile? profile;
      if (profileName != null) {
        profile = await _profileService.getOrCreateProfile(profileName);
      } else {
        final profiles = _profileService.getAllProfiles();
        if (profiles.isNotEmpty) {
          profile = profiles.first;
        } else {
          profile = await _profileService.createProfile(name: 'Default');
        }
      }

      if (profile == null) {
        return 'Failed to create or find profile.';
      }

      // Create ring now alarm
      final alarmId = await _alarmService.createRingNowAlarm();
      
      if (alarmId == null) {
        return 'Failed to create test alarm.';
      }

      // Add to profile
      await _profileService.addAlarmToProfile(profile.id, alarmId);

      return 'Ringing alarm now in profile "${profile.name}".';
    } catch (e) {
      _log.severe('Error handling ring now: $e');
      return 'Failed to ring alarm: $e';
    }
  }

  /// Handle show alarms command
  Future<String> _handleShowAlarms(ParsedSpeechCommand command) async {
    try {
      final alarms = await _alarmService.getActiveAlarms();
      
      if (alarms.isEmpty) {
        return 'You have no active alarms.';
      }

      final count = alarms.length;
      final next = alarms.first;
      final label = _alarmService.getAlarmLabel(next);
      
      if (count == 1) {
        return 'You have 1 alarm. Next alarm is $label.';
      } else {
        return 'You have $count alarms. Next alarm is $label.';
      }
    } catch (e) {
      _log.severe('Error handling show alarms: $e');
      return 'Failed to get alarms: $e';
    }
  }

  void showVoiceCommandsHelp(BuildContext context) {
    _log.info('Showing voice commands help dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Voice Commands'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: SpeechCommand.values
                .where((cmd) => cmd != SpeechCommand.unknown)
                .map((cmd) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cmd.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cmd.examples.join('\n'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  
}
