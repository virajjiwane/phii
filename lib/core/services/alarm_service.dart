
import 'package:alarm/alarm.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:logging/logging.dart';
import 'package:phii/models/profile.dart';

/// Service that handles all alarm-related operations
/// Provides a centralized API for creating, managing, and querying alarms
class AlarmService {
  static final _log = Logger('AlarmService');

  /// Create and set a new alarm
  /// Returns the alarm ID if successful, null otherwise
  Future<int?> createAlarm(AlarmSettings alarmSettings) async {
    try {
      _log.info('Creating alarm with ID: ${alarmSettings.id} at ${alarmSettings.dateTime}');
      final result = await Alarm.set(alarmSettings: alarmSettings);
      if (result) {
        _log.fine('Alarm created successfully');
        return alarmSettings.id;
      } else {
        _log.warning('Failed to create alarm');
        return null;
      }
    } catch (e) {
      _log.severe('Error creating alarm: $e');
      return null;
    }
  }

  /// Build AlarmSettings with common defaults
  AlarmSettings buildAlarmSettings({
    required DateTime dateTime,
    int? id,
    bool loopAudio = true,
    bool vibrate = true,
    double? volume,
    Duration? fadeDuration,
    bool staircaseFade = false,
    String assetAudioPath = 'assets/marimba.mp3',
    String title = 'Phii Time! ⏰',
    String body = 'Wake up! It\'s Phii time to rise and shine! ☀️',
  }) {
    final alarmId = id ?? DateTime.now().millisecondsSinceEpoch % 10000 + 1;

    final VolumeSettings volumeSettings;
    if (staircaseFade) {
      volumeSettings = VolumeSettings.staircaseFade(
        volume: volume,
        fadeSteps: [
          VolumeFadeStep(Duration.zero, 0),
          VolumeFadeStep(const Duration(seconds: 15), 0.03),
          VolumeFadeStep(const Duration(seconds: 20), 0.5),
          VolumeFadeStep(const Duration(seconds: 30), 1),
        ],
      );
    } else if (fadeDuration != null) {
      volumeSettings = VolumeSettings.fade(
        volume: volume,
        fadeDuration: fadeDuration,
      );
    } else {
      volumeSettings = VolumeSettings.fixed(volume: volume);
    }

    return AlarmSettings(
      id: alarmId,
      dateTime: dateTime,
      loopAudio: loopAudio,
      vibrate: vibrate,
      assetAudioPath: assetAudioPath,
      volumeSettings: volumeSettings,
      allowAlarmOverlap: true,
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop the alarm',
        icon: 'notification_icon',
      ),
    );
  }

  /// Create an alarm that rings immediately (for testing)
  Future<int?> createRingNowAlarm({String? profileId}) async {
    _log.info('Creating ring now alarm');
    final now = DateTime.now();
    final alarmSettings = buildAlarmSettings(
      dateTime: now,
      title: 'Test Alarm',
      body: 'Testing alarm sound',
    );
    return await createAlarm(alarmSettings);
  }

  /// Create an alarm at a specific time
  Future<int?> createAlarmAt({
    required DateTime dateTime,
    String title = 'Phii Time! ⏰',
    String body = 'Wake up! It\'s Phii time to rise and shine! ☀️',
  }) async {
    _log.info('Creating alarm at $dateTime');
    final alarmSettings = buildAlarmSettings(
      dateTime: dateTime,
      title: title,
      body: body,
    );
    return await createAlarm(alarmSettings);
  }

  /// Create an alarm after a duration from now
  Future<int?> createAlarmIn({
    required Duration duration,
    String title = 'Phii Time! ⏰',
    String body = 'Wake up! It\'s Phii time to rise and shine! ☀️',
  }) async {
    final dateTime = DateTime.now().add(duration);
    _log.info('Creating alarm in ${duration.inMinutes} minutes at $dateTime');
    return await createAlarmAt(dateTime: dateTime, title: title, body: body);
  }

  /// Stop a specific alarm
  Future<bool> stopAlarm(int alarmId) async {
    try {
      _log.info('Stopping alarm: $alarmId');
      final result = await Alarm.stop(alarmId);
      _log.fine('Alarm stopped: $result');
      return result;
    } catch (e) {
      _log.severe('Error stopping alarm $alarmId: $e');
      return false;
    }
  }

  /// Get alarm by ID
  Future<AlarmSettings?> getAlarm(int alarmId) async {
    try {
      _log.fine('Getting alarm: $alarmId');
      return await Alarm.getAlarm(alarmId);
    } catch (e) {
      _log.severe('Error getting alarm $alarmId: $e');
      return null;
    }
  }

  /// Get the most recent (soonest) alarm from a list of alarm IDs
  Future<AlarmSettings?> getMostRecentAlarm(List<int> alarmIds) async {
    if (alarmIds.isEmpty) {
      _log.fine('No alarm IDs provided');
      return null;
    }

    _log.fine('Getting most recent alarm from ${alarmIds.length} alarms');
    AlarmSettings? mostRecent;
    DateTime? closestTime;
    final now = DateTime.now();

    for (final alarmId in alarmIds) {
      final alarm = await getAlarm(alarmId);
      if (alarm != null) {
        final difference = alarm.dateTime.difference(now);
        if (!difference.isNegative) {
          if (closestTime == null || alarm.dateTime.isBefore(closestTime)) {
            closestTime = alarm.dateTime;
            mostRecent = alarm;
          }
        }
      }
    }

    _log.fine('Most recent alarm: ${mostRecent?.id ?? "none"}');
    return mostRecent;
  }

  /// Get a human-readable label for when an alarm will ring
  String getAlarmLabel(AlarmSettings alarm) {
    final now = DateTime.now();
    final alarmTime = alarm.dateTime;
    final difference = alarmTime.difference(now);

    if (difference.isNegative) {
      return 'Passed';
    } else if (difference.inMinutes < 60) {
      return 'In ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return 'In ${difference.inHours} hours';
    } else {
      final days = difference.inDays;
      return 'In $days day${days > 1 ? 's' : ''}';
    }
  }

  /// Delete an alarm (stops it and removes from profile if provided)
  Future<bool> deleteAlarm(int alarmId, {String? profileId}) async {
    _log.info('Deleting alarm: $alarmId from profile: $profileId');
    
    final stopped = await stopAlarm(alarmId);
    if (!stopped) {
      _log.warning('Failed to stop alarm $alarmId');
      return false;
    }

    // Remove from profile if provided
    if (profileId != null) {
      try {
        final profilesBox = Hive.box<Profile>('profiles');
        final profile = profilesBox.get(profileId);
        if (profile != null) {
          profile.alarmIds.remove(alarmId);
          await profile.save();
          _log.fine('Removed alarm from profile');
          
          // Delete profile if no alarms remain
          if (profile.alarmIds.isEmpty) {
            await profilesBox.delete(profileId);
            _log.info('Deleted empty profile: $profileId');
          }
        }
      } catch (e) {
        _log.severe('Error removing alarm from profile: $e');
      }
    }

    return true;
  }

  /// Stop all alarms across all profiles
  Future<int> stopAllAlarms() async {
    _log.info('Stopping all alarms');
    int stoppedCount = 0;
    
    try {
      final profilesBox = Hive.box<Profile>('profiles');
      final profiles = profilesBox.values.toList();
      
      for (final profile in profiles) {
        for (final alarmId in profile.alarmIds.toList()) {
          final stopped = await stopAlarm(alarmId);
          if (stopped) {
            stoppedCount++;
            profile.alarmIds.remove(alarmId);
          }
        }
        await profile.save();
      }
      
      _log.info('Stopped $stoppedCount alarms');
    } catch (e) {
      _log.severe('Error stopping all alarms: $e');
    }
    
    return stoppedCount;
  }

  /// Check if an alarm exists
  Future<bool> alarmExists(int alarmId) async {
    final alarm = await getAlarm(alarmId);
    return alarm != null;
  }

  /// Get all active alarms (that haven't passed)
  Future<List<AlarmSettings>> getActiveAlarms() async {
    _log.fine('Getting all active alarms');
    final now = DateTime.now();
    final profilesBox = Hive.box<Profile>('profiles');
    final profiles = profilesBox.values.toList();
    
    final List<AlarmSettings> activeAlarms = [];
    
    for (final profile in profiles) {
      for (final alarmId in profile.alarmIds) {
        final alarm = await getAlarm(alarmId);
        if (alarm != null && alarm.dateTime.isAfter(now)) {
          activeAlarms.add(alarm);
        }
      }
    }
    
    // Sort by datetime
    activeAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    _log.fine('Found ${activeAlarms.length} active alarms');
    return activeAlarms;
  }
}