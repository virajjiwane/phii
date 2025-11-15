import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:phii/core/services/notifications.dart';
import 'package:phii/screens/edit_alarm.dart';
import 'package:phii/screens/shortcut_button.dart';
import 'package:phii/widgets/tile.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/profile.dart';
import '../core/services/alarm_service.dart';
import '../core/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profileId});
  
  final String profileId;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
   
  Notifications? notifications;
  late Box<Profile> profilesBox;
  late String selectedProfileId;
  final AlarmService _alarmService = AlarmService();
  final ProfileService _profileService = ProfileService();

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize profiles box
    profilesBox = Hive.box<Profile>('profiles');
    selectedProfileId = widget.profileId;
    
    // FAB animation controller
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final result = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: EditAlarmScreen(
            alarmSettings: settings,
            profileId: selectedProfileId,
            // No onAlarmCreated callback needed here
          ),
        );
      },
    );
    
    // Refresh alarms if needed
    if (result == true) {
      setState(() {});
    }
  }

  void _deleteAlarm(int alarmId) {
    // Delete alarm using AlarmService
    _alarmService.deleteAlarm(alarmId, profileId: selectedProfileId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: ValueListenableBuilder(
          valueListenable: profilesBox.listenable(),
          builder: (context, Box<Profile> box, _) {
            final profile = box.get(selectedProfileId);
            return Text(
              profile?.name ?? 'Alarms',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            onPressed: _showDeleteProfileDialog,
            tooltip: 'Delete Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: profilesBox.listenable(),
          builder: (context, Box<Profile> box, _) {
            final profile = box.get(selectedProfileId);
            bool profileHasAlarms = false;
            final alarmIds;
            if (profile != null) {
              profileHasAlarms = profile.alarmIds.isNotEmpty;
              alarmIds = profile.alarmIds;
            } else {
              alarmIds = [];
            }
            return profileHasAlarms
                ? _buildAlarmsList(alarmIds)
                : _buildEmptyState(colorScheme, textTheme);
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder(
        valueListenable: profilesBox.listenable(),
        builder: (context, Box<Profile> box, _) {
          final profile = box.get(selectedProfileId);
          final alarmIds = profile?.alarmIds ?? [];
          return _buildFloatingActionButtons(colorScheme, alarmIds);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No alarms set',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first alarm',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),
          
          // Big circular "+" button
          GestureDetector(
            onTapDown: (_) => _fabAnimationController.forward(),
            onTapUp: (_) => _fabAnimationController.reverse(),
            onTapCancel: () => _fabAnimationController.reverse(),
            child: ScaleTransition(
              scale: _fabScaleAnimation,
              child: InkWell(
                onTap: () => navigateToAlarmScreen(null),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Small RING NOW button
          TextButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final alarmId = DateTime.now().millisecondsSinceEpoch % 10000;
              final alarmSettings = AlarmSettings(
                id: alarmId,
                dateTime: now,
                assetAudioPath: 'assets/marimba.mp3',
                volumeSettings: VolumeSettings.fixed(volume: 0.5),
                notificationSettings: const NotificationSettings(
                  title: 'Quick Alarm',
                  body: 'Immediate alarm',
                  icon: 'notification_icon',
                ),
              );
              await Alarm.set(alarmSettings: alarmSettings);
              
              // Add to current profile
              final profile = profilesBox.get(selectedProfileId);
              if (profile != null) {
                profile.alarmIds.add(alarmId);
                await profile.save();
              }
            },
            icon: Icon(
              Icons.alarm_on_rounded,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            label: Text(
              'RING NOW',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmsList(List<int> alarmIds) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: alarmIds.length,
      itemBuilder: (context, index) {
        final alarmId = alarmIds[index];
        return FutureBuilder<AlarmSettings?>(
          future: Alarm.getAlarm(alarmId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            
            final alarm = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AlarmTile(
                key: Key(alarmId.toString()),
                title: TimeOfDay(
                  hour: alarm.dateTime.hour,
                  minute: alarm.dateTime.minute,
                ).format(context),
                subtitle: _getAlarmLabel(alarm),
                onPressed: () => navigateToAlarmScreen(alarm),
                onDismissed: () => _deleteAlarm(alarmId),
              ),
            );
          },
        );
      },
    );
  }

  String _getAlarmLabel(AlarmSettings alarm) {
    return _alarmService.getAlarmLabel(alarm);
  }

  Widget _buildFloatingActionButtons(ColorScheme colorScheme, List<int> alarmIds) {
    if (alarmIds.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Quick alarm button
          ExampleAlarmHomeShortcutButton(
            refreshAlarms: () => setState(() {}),
            profileId: selectedProfileId,
          ),
          
          Row(
            children: [
              // Stop all button
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.error.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Stop all alarms in profile using ProfileService
                      _profileService.stopAllAlarmsInProfile(selectedProfileId);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stop_circle_outlined,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stop All',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Add alarm button
              ScaleTransition(
                scale: _fabScaleAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _fabAnimationController.forward().then(
                          (_) => _fabAnimationController.reverse()
                        );
                        navigateToAlarmScreen(null);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete Profile'),
        content: const Text('Are you sure you want to delete this profile? All alarms in this profile will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Delete profile using ProfileService
              _profileService.deleteProfile(selectedProfileId, stopAlarms: true);
              // Navigate back to home screen
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home screen
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}