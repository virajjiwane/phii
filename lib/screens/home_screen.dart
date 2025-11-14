import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:phii/screens/ring.dart';
import '../models/profile.dart';
import '../core/themes/app_theme.dart';
import 'profile_screen.dart';
import 'edit_alarm.dart';
import 'settings_screen.dart';
import '../core/services/speech_service.dart';
import '../core/services/permission.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:logging/logging.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static final _log = Logger('HomeScreen');

  @override
  State<HomeScreen> createState() {
    _log.info('Creating HomeScreen state');
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen>
  with SingleTickerProviderStateMixin {
  static final _log = Logger('_HomeScreenState');
  late Box<Profile> profilesBox;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late SpeechService _speechService;
  bool _isListening = false;
  String _recognizedText = '';
  bool _showSpeechBubble = false;
  static StreamSubscription<AlarmSet>? ringSubscription;

  @override
  void initState() {
  super.initState();
  _log.info('Initializing HomeScreen state');

  // Initialize profiles box
  profilesBox = Hive.box<Profile>('profiles');
  _log.fine('Profiles box initialized with ${profilesBox.length} profiles');

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
  requestMicrophonePermission().then((granted) {
    _log.info('Microphone permission granted: $granted');
    if (!granted) {
    // Show a snackbar or dialog to inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
      content: Text('Microphone permission is required for voice commands.'),
      ),
    );
    } else {
    // Optionally show a confirmation that permission was granted
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
      content: Text('Microphone permission granted. You can now use voice commands.'),
      ),
    );
    }
  });
  ringSubscription ??= Alarm.ringing.listen(ringingAlarmsChanged);

  _initializeSpeech();
  }

  void ringingAlarmsChanged(AlarmSet alarms) async {
  _log.info('Ringing alarms changed: ${alarms.alarms.length} alarms');
  if (alarms.alarms.isEmpty) return;
  _log.fine('Navigating to alarm ring screen for alarm ID: ${alarms.alarms.first.id}');
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
    builder: (context) =>
      AlarmRingScreen(alarmSettings: alarms.alarms.first),
    ),
  );
  }

  void _initializeSpeech() {
  _log.info('Initializing speech service');
  _speechService = SpeechService();

  _speechService.onSpeechResult = (text) {
    _log.fine('Speech result: $text');
    setState(() {
    _recognizedText = text;
    _showSpeechBubble = true;
    });
  };

  _speechService.onListeningStateChanged = (isListening) {
    _log.fine('Listening state changed: $isListening');
    setState(() {
    _isListening = isListening;
    if (!isListening) {
      // Hide speech bubble after a delay when listening stops
      Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
        _showSpeechBubble = false;
        });
      }
      });
    }
    });
  };
  }

  void _showCommandFeedback(String message) {
  _log.fine('Showing command feedback: $message');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
    content: Row(
      children: [
      const Icon(Icons.mic, color: Colors.white),
      const SizedBox(width: 8),
      Expanded(child: Text(message)),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
  }

  void _showVoiceCommandsHelp() {
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
              cmd.example,
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

  void _toggleSpeechListening(BuildContext context) async {
  _log.info('Toggling speech listening, current state: $_isListening');
  if (_isListening) {
    await _speechService.stopListening();
  } else {
    final initialized = await _speechService.initialize(context);
    _log.fine('Speech service initialized: $initialized');
    if (initialized) {
    await _speechService.startListening(context);
    } else {
    _showCommandFeedback('Speech recognition not available');
    }
  }
  }
  
  @override
  void dispose() {
  _log.info('Disposing HomeScreen state');
  _fabAnimationController.dispose();
  _speechService.dispose();
  ringSubscription?.cancel();
  super.dispose();
  }

  Future<AlarmSettings?> _getMostRecentAlarm(Profile profile) async {
  _log.fine('Getting most recent alarm for profile: ${profile.name}');
  if (profile.alarmIds.isEmpty) return null;

  AlarmSettings? mostRecent;
  DateTime? closestTime;
  final now = DateTime.now();

  for (final alarmId in profile.alarmIds) {
    final alarm = await Alarm.getAlarm(alarmId);
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

  void _navigateToProfile(String profileId) {
  _log.info('Navigating to profile: $profileId');
  Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => ProfileScreen(profileId: profileId),
    ),
  );
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
      'Phii',
      style: AppTheme.homeTitleStyle,
    ),
    centerTitle: false,
    actions: [
      // Voice command button
      IconButton(
      icon: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: _isListening ? Colors.red : colorScheme.primary,
      ),
      onPressed: () => _toggleSpeechListening(context),
      tooltip: 'Voice Commands',
      ),
      PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (value) {
        _log.fine('Menu item selected: $value');
        if (value == 'settings') {
        Navigator.push(
          context,
          MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
          ),
        );
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
        value: 'settings',
        child: Row(
          children: [
          Icon(Icons.settings_outlined,
            color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          const Text('Settings'),
          ],
        ),
        ),
      ],
      ),
    ],
    ),
    body: SafeArea(
    child: Stack(
      children: [
      ValueListenableBuilder(
        valueListenable: profilesBox.listenable(),
        builder: (context, Box<Profile> box, _) {
        final profiles = box.values.toList();
        _log.fine('Building profiles list with ${profiles.length} profiles');

        return profiles.isEmpty
          ? _buildEmptyState(colorScheme, textTheme)
          : _buildProfilesList(profiles, colorScheme, textTheme);
        },
      ),
      // Speech bubble overlay
      if (_showSpeechBubble && _recognizedText.isNotEmpty)
        Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: AnimatedOpacity(
          opacity: _showSpeechBubble ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            ],
          ),
          child: Row(
            children: [
            Icon(
              _isListening ? Icons.mic : Icons.check_circle,
              color: _isListening
                ? Colors.red
                : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
              _recognizedText,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
              ),
            ),
            ],
          ),
          ),
        ),
        ),
      ],
    ),
    ),
    floatingActionButton: ValueListenableBuilder(
    valueListenable: profilesBox.listenable(),
    builder: (context, Box<Profile> box, _) {
      final profiles = box.values.toList();
      return profiles.isEmpty
        ? const SizedBox.shrink()
        : _buildFloatingActionButton(colorScheme);
    },
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
  _log.fine('Building empty state');
  return Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.alarm_off_outlined,
        size: 24, color: colorScheme.onSurface.withValues(alpha: 0.6)),
      const SizedBox(width: 8),
      Text(
        'No Alarms',
        style: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        ),
      ),
      ]),
      const SizedBox(height: 8),
      Text(
      'Create your first alarm!',
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
        onTap: _showCreateProfileDialog,
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
    ],
    ),
  );
  }

  Widget _buildProfilesList(
    List<Profile> profiles, ColorScheme colorScheme, TextTheme textTheme) {
  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: profiles.length,
    itemBuilder: (context, index) {
    final profile = profiles[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildProfileCard(profile, colorScheme, textTheme),
    );
    },
  );
  }

  Widget _buildProfileCard(
    Profile profile, ColorScheme colorScheme, TextTheme textTheme) {
  return FutureBuilder<AlarmSettings?>(
    future: _getMostRecentAlarm(profile),
    builder: (context, snapshot) {
    final mostRecentAlarm = snapshot.data;

    return Dismissible(
      key: Key(profile.id),
      direction: DismissDirection.endToStart,
      background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onError,
          size: 28,
        ),
        const SizedBox(height: 4),
        Text(
          'Delete',
          style: TextStyle(
          color: colorScheme.onError,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          ),
        ),
        ],
      ),
      ),
      confirmDismiss: (direction) => _confirmDeleteProfile(profile),
      onDismissed: (direction) => _deleteProfile(profile),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToProfile(profile.id),
        borderRadius: BorderRadius.circular(24),
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          ],
        ),
        child: Row(
          children: [
          // Profile Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            ),
            child: Icon(
            Icons.folder_outlined,
            color: colorScheme.primary,
            size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Profile Info
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
              profile.name,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
              ),
              const SizedBox(height: 4),
              if (mostRecentAlarm != null)
              Row(
                children: [
                Icon(
                  Icons.alarm_rounded,
                  size: 16,
                  color: colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  TimeOfDay(
                  hour: mostRecentAlarm.dateTime.hour,
                  minute: mostRecentAlarm.dateTime.minute,
                  ).format(context),
                  style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${_getAlarmLabel(mostRecentAlarm)}',
                  style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.7),
                  ),
                ),
                ],
              )
              else
              Row(
                children: [
                Icon(
                  Icons.alarm_off_rounded,
                  size: 16,
                  color: colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'No alarms set',
                  style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.6),
                  ),
                ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
              '${profile.alarmIds.length} alarm${profile.alarmIds.length != 1 ? 's' : ''}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer
                  .withValues(alpha: 0.5),
              ),
              ),
            ],
            ),
          ),

          // Arrow
          Icon(
            Icons.arrow_forward_ios_rounded,
            color:
              colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
            size: 18,
          ),
          ],
        ),
        ),
      ),
      ),
    );
    },
  );
  }

  Widget _buildFloatingActionButton(ColorScheme colorScheme) {
  return ScaleTransition(
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
        _log.info('FAB tapped - showing create profile dialog');
        _fabAnimationController
          .forward()
          .then((_) => _fabAnimationController.reverse());
        _showCreateProfileDialog();
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
  );
  }

  void _showCreateProfileDialog() async {
  _log.info('Showing create profile dialog');
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
      alarmSettings: null,
      profileId: null, // null means create new profile
      onAlarmCreated: (alarmSettings, profileId) {
        _log.info('Alarm created with profile ID: $profileId');
        // Navigate to the newly created profile
        if (profileId != null) {
        _navigateToProfile(profileId);
        }
      },
      ),
    );
    },
  );
  _log.fine('Create profile dialog closed with result: $result');
  }

  Future<bool?> _confirmDeleteProfile(Profile profile) {
  _log.info('Confirming delete for profile: ${profile.name}');
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    title: const Text('Delete Profile'),
    content: Text(
      'Are you sure you want to delete "${profile.name}"? All alarms in this profile will be removed.',
    ),
    actions: [
      TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: const Text('Cancel'),
      ),
      FilledButton(
      onPressed: () => Navigator.pop(context, true),
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      child: const Text('Delete'),
      ),
    ],
    ),
  );
  }

  void _deleteProfile(Profile profile) {
  _log.info('Deleting profile: ${profile.name} with ${profile.alarmIds.length} alarms');
  // Stop all alarms in the profile
  for (final alarmId in profile.alarmIds) {
    _log.fine('Stopping alarm: $alarmId');
    Alarm.stop(alarmId);
  }
  // Delete the profile
  profilesBox.delete(profile.id);
  _log.info('Profile deleted: ${profile.id}');
  }
}
