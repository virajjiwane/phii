import 'package:phii/models/profile.dart';
import 'package:logging/logging.dart';
import 'package:alarm/alarm.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'alarm_service.dart';

/// Service that handles all profile-related operations
/// Provides a centralized API for creating, managing, and querying profiles
class ProfileService {
  static final _log = Logger('ProfileService');
  final AlarmService _alarmService = AlarmService();

  /// Get the profiles box
  Box<Profile> get _profilesBox => Hive.box<Profile>('profiles');

  /// Create a new profile
  Future<Profile?> createProfile({
    required String name,
    List<int>? initialAlarmIds,
  }) async {
    try {
      _log.info('Creating profile: $name');
      
      if (name.trim().isEmpty) {
        _log.warning('Cannot create profile with empty name');
        return null;
      }

      final profile = Profile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        alarmIds: initialAlarmIds ?? [],
      );

      await _profilesBox.put(profile.id, profile);
      _log.fine('Profile created with ID: ${profile.id}');
      
      return profile;
    } catch (e) {
      _log.severe('Error creating profile: $e');
      return null;
    }
  }

  /// Get a profile by ID
  Profile? getProfile(String profileId) {
    try {
      _log.fine('Getting profile: $profileId');
      return _profilesBox.get(profileId);
    } catch (e) {
      _log.severe('Error getting profile $profileId: $e');
      return null;
    }
  }

  /// Get all profiles
  List<Profile> getAllProfiles() {
    try {
      _log.fine('Getting all profiles');
      return _profilesBox.values.toList();
    } catch (e) {
      _log.severe('Error getting all profiles: $e');
      return [];
    }
  }

  /// Check if a profile exists
  bool profileExists(String profileId) {
    return _profilesBox.containsKey(profileId);
  }

  /// Update profile name
  Future<bool> updateProfileName(String profileId, String newName) async {
    try {
      if (newName.trim().isEmpty) {
        _log.warning('Cannot update profile with empty name');
        return false;
      }

      final profile = getProfile(profileId);
      if (profile == null) {
        _log.warning('Profile not found: $profileId');
        return false;
      }

      _log.info('Updating profile name: $profileId to $newName');
      profile.name = newName.trim();
      await profile.save();
      
      return true;
    } catch (e) {
      _log.severe('Error updating profile name: $e');
      return false;
    }
  }

  /// Add an alarm to a profile
  Future<bool> addAlarmToProfile(String profileId, int alarmId) async {
    try {
      final profile = getProfile(profileId);
      if (profile == null) {
        _log.warning('Profile not found: $profileId');
        return false;
      }

      if (profile.alarmIds.contains(alarmId)) {
        _log.fine('Alarm $alarmId already in profile $profileId');
        return true;
      }

      _log.info('Adding alarm $alarmId to profile $profileId');
      profile.alarmIds.add(alarmId);
      await profile.save();
      
      return true;
    } catch (e) {
      _log.severe('Error adding alarm to profile: $e');
      return false;
    }
  }

  /// Remove an alarm from a profile
  Future<bool> removeAlarmFromProfile(String profileId, int alarmId) async {
    try {
      final profile = getProfile(profileId);
      if (profile == null) {
        _log.warning('Profile not found: $profileId');
        return false;
      }

      _log.info('Removing alarm $alarmId from profile $profileId');
      profile.alarmIds.remove(alarmId);
      await profile.save();
      
      // Delete profile if no alarms remain
      if (profile.alarmIds.isEmpty) {
        _log.info('Profile $profileId is empty, deleting');
        await deleteProfile(profileId);
      }
      
      return true;
    } catch (e) {
      _log.severe('Error removing alarm from profile: $e');
      return false;
    }
  }

  /// Delete a profile and all its alarms
  Future<bool> deleteProfile(String profileId, {bool stopAlarms = true}) async {
    try {
      final profile = getProfile(profileId);
      if (profile == null) {
        _log.warning('Profile not found: $profileId');
        return false;
      }

      _log.info('Deleting profile: $profileId (${profile.alarmIds.length} alarms)');

      // Stop all alarms in the profile if requested
      if (stopAlarms) {
        for (final alarmId in profile.alarmIds.toList()) {
          await _alarmService.stopAlarm(alarmId);
        }
      }

      // Delete the profile
      await _profilesBox.delete(profileId);
      _log.fine('Profile deleted: $profileId');
      
      return true;
    } catch (e) {
      _log.severe('Error deleting profile: $e');
      return false;
    }
  }

  /// Get the most recent alarm for a profile
  Future<AlarmSettings?> getMostRecentAlarmForProfile(String profileId) async {
    final profile = getProfile(profileId);
    if (profile == null) {
      _log.warning('Profile not found: $profileId');
      return null;
    }

    return await _alarmService.getMostRecentAlarm(profile.alarmIds);
  }

  /// Get all alarms for a profile
  Future<List<AlarmSettings>> getAlarmsForProfile(String profileId) async {
    final profile = getProfile(profileId);
    if (profile == null) {
      _log.warning('Profile not found: $profileId');
      return [];
    }

    final List<AlarmSettings> alarms = [];
    for (final alarmId in profile.alarmIds) {
      final alarm = await _alarmService.getAlarm(alarmId);
      if (alarm != null) {
        alarms.add(alarm);
      }
    }

    // Sort by datetime
    alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    return alarms;
  }

  /// Stop all alarms in a profile
  Future<int> stopAllAlarmsInProfile(String profileId) async {
    final profile = getProfile(profileId);
    if (profile == null) {
      _log.warning('Profile not found: $profileId');
      return 0;
    }

    _log.info('Stopping all alarms in profile: $profileId');
    int stoppedCount = 0;

    for (final alarmId in profile.alarmIds.toList()) {
      final stopped = await _alarmService.stopAlarm(alarmId);
      if (stopped) {
        stoppedCount++;
        profile.alarmIds.remove(alarmId);
      }
    }

    await profile.save();
    
    // Delete profile if empty
    if (profile.alarmIds.isEmpty) {
      await deleteProfile(profileId, stopAlarms: false);
    }

    _log.info('Stopped $stoppedCount alarms in profile $profileId');
    return stoppedCount;
  }

  /// Get profile count
  int getProfileCount() {
    return _profilesBox.length;
  }

  /// Check if profile has any alarms
  bool profileHasAlarms(String profileId) {
    final profile = getProfile(profileId);
    return profile != null && profile.alarmIds.isNotEmpty;
  }

  /// Get profile name by ID
  String? getProfileName(String profileId) {
    final profile = getProfile(profileId);
    return profile?.name;
  }

  /// Find profile by name (case insensitive)
  Profile? findProfileByName(String name) {
    try {
      final profiles = getAllProfiles();
      final normalizedName = name.trim().toLowerCase();
      
      for (final profile in profiles) {
        if (profile.name.toLowerCase() == normalizedName) {
          return profile;
        }
      }
      
      return null;
    } catch (e) {
      _log.severe('Error finding profile by name: $e');
      return null;
    }
  }

  /// Create profile with an alarm
  Future<Profile?> createProfileWithAlarm({
    required String profileName,
    required AlarmSettings alarmSettings,
  }) async {
    try {
      _log.info('Creating profile with alarm: $profileName');
      
      // Create the alarm first
      final alarmId = await _alarmService.createAlarm(alarmSettings);
      if (alarmId == null) {
        _log.warning('Failed to create alarm for profile');
        return null;
      }

      // Create the profile
      final profile = await createProfile(
        name: profileName,
        initialAlarmIds: [alarmId],
      );

      return profile;
    } catch (e) {
      _log.severe('Error creating profile with alarm: $e');
      return null;
    }
  }

  /// Get or create a profile by name
  Future<Profile?> getOrCreateProfile(String name) async {
    // Try to find existing profile
    var profile = findProfileByName(name);
    
    if (profile != null) {
      _log.fine('Found existing profile: $name');
      return profile;
    }

    // Create new profile
    _log.info('Creating new profile: $name');
    return await createProfile(name: name);
  }

  /// Clean up profiles with no alarms
  Future<int> cleanupEmptyProfiles() async {
    _log.info('Cleaning up empty profiles');
    int deletedCount = 0;

    try {
      final profiles = getAllProfiles();
      
      for (final profile in profiles) {
        if (profile.alarmIds.isEmpty) {
          await deleteProfile(profile.id, stopAlarms: false);
          deletedCount++;
        }
      }
      
      _log.info('Deleted $deletedCount empty profiles');
    } catch (e) {
      _log.severe('Error cleaning up profiles: $e');
    }

    return deletedCount;
  }

  /// Validate profile data integrity
  /// Removes alarm IDs that don't have corresponding alarms
  Future<void> validateProfileIntegrity(String profileId) async {
    try {
      final profile = getProfile(profileId);
      if (profile == null) return;

      _log.fine('Validating profile integrity: $profileId');
      final invalidAlarmIds = <int>[];

      for (final alarmId in profile.alarmIds) {
        final exists = await _alarmService.alarmExists(alarmId);
        if (!exists) {
          invalidAlarmIds.add(alarmId);
        }
      }

      if (invalidAlarmIds.isNotEmpty) {
        _log.warning('Found ${invalidAlarmIds.length} invalid alarm IDs in profile $profileId');
        profile.alarmIds.removeWhere((id) => invalidAlarmIds.contains(id));
        await profile.save();
        
        if (profile.alarmIds.isEmpty) {
          await deleteProfile(profileId, stopAlarms: false);
        }
      }
    } catch (e) {
      _log.severe('Error validating profile integrity: $e');
    }
  }

  /// Validate all profiles
  Future<void> validateAllProfiles() async {
    _log.info('Validating all profiles');
    final profiles = getAllProfiles();
    
    for (final profile in profiles) {
      await validateProfileIntegrity(profile.id);
    }
  }
}