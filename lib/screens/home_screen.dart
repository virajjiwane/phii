import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:phii/core/services/notifications.dart';
import 'package:phii/core/services/permission.dart';
import 'package:phii/screens/ring.dart';
import 'package:phii/screens/edit_alarm.dart';
import 'package:phii/screens/shortcut_button.dart';
import 'package:phii/widgets/tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
   List<AlarmSettings> alarms = [];
  Notifications? notifications;

  static StreamSubscription<AlarmSet>? ringSubscription;
  static StreamSubscription<AlarmSet>? updateSubscription;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // FAB animation controller
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    
    AlarmPermissions.checkNotificationPermission().then(
      (_) => AlarmPermissions.checkAndroidScheduleExactAlarmPermission(),
    );
    loadAlarms();
    ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);
    updateSubscription ??= Alarm.scheduled.listen((_) {
      loadAlarms();
    });
  }

  @override
  void dispose() {
    ringSubscription?.cancel();
    updateSubscription?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void loadAlarms() async {
    final updatedAlarms = await Alarm.getAlarms();
    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    setState(() {
      alarms = updatedAlarms;
    });
  }

  void ringingAlarmsChanged(AlarmSet alarms) async {
    if (alarms.alarms.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            AlarmRingScreen(alarmSettings: alarms.alarms.first),
      ),
    );
    loadAlarms();
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: EditAlarmScreen(alarmSettings: settings),
        );
      },
    );

    if (res != null && res == true) loadAlarms();
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
        title: Text(
          'Alarms',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          if (notifications != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) async {
                if (value == 'Show notification') {
                  await notifications?.showNotification();
                } else if (value == 'Schedule notification') {
                  await notifications?.scheduleNotification();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'Show notification',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, 
                        color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      const Text('Show notification'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'Schedule notification',
                  child: Row(
                    children: [
                      Icon(Icons.schedule_outlined, 
                        color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      const Text('Schedule notification'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: alarms.isEmpty 
            ? _buildEmptyState(colorScheme, textTheme)
            : _buildAlarmsList(),
      ),
      floatingActionButton: _buildFloatingActionButtons(colorScheme),
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
              final alarmSettings = AlarmSettings(
                id: DateTime.now().millisecondsSinceEpoch % 10000,
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
              loadAlarms();
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

  Widget _buildAlarmsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AlarmTile(
            key: Key(alarms[index].id.toString()),
            title: TimeOfDay(
              hour: alarms[index].dateTime.hour,
              minute: alarms[index].dateTime.minute,
            ).format(context),
            subtitle: _getAlarmLabel(alarms[index]),
            onPressed: () => navigateToAlarmScreen(alarms[index]),
            onDismissed: () {
              Alarm.stop(alarms[index].id).then((_) => loadAlarms());
            },
          ),
        );
      },
    );
  }

  String _getAlarmLabel(AlarmSettings alarm) {
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

  Widget _buildFloatingActionButtons(ColorScheme colorScheme) {
    if (alarms.isEmpty) {
      return const SizedBox.shrink(); // No FAB when no alarms
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Quick alarm button
          ExampleAlarmHomeShortcutButton(refreshAlarms: loadAlarms),
          
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
                      Alarm.stopAll().then((_) => loadAlarms());
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
}