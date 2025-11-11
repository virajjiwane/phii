import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AlarmHomePage(),
    );
  }
}

class Alarm {
  final String id;
  final TimeOfDay time;
  final String label;
  bool isActive;

  Alarm({
    required this.id,
    required this.time,
    required this.label,
    this.isActive = true,
  });
}

class AlarmHomePage extends StatefulWidget {
  const AlarmHomePage({super.key});

  @override
  State<AlarmHomePage> createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  final List<Alarm> _alarms = [];
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    // Check every second if any alarm should ring
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAlarms();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  void _checkAlarms() {
    final now = TimeOfDay.now();
    for (var alarm in _alarms) {
      if (alarm.isActive && 
          alarm.time.hour == now.hour && 
          alarm.time.minute == now.minute) {
        _showAlarmDialog(alarm);
      }
    }
  }

  void _showAlarmDialog(Alarm alarm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.alarm, color: Colors.red, size: 32),
              SizedBox(width: 10),
              Text('Alarm!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${alarm.time.format(context)}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                alarm.label,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  alarm.isActive = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Turn Off'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addAlarm() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final TextEditingController labelController = TextEditingController();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Set Alarm Label'),
            content: TextField(
              controller: labelController,
              decoration: const InputDecoration(
                hintText: 'Enter alarm label (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _alarms.add(Alarm(
                      id: DateTime.now().toString(),
                      time: pickedTime,
                      label: labelController.text.isEmpty 
                          ? 'Alarm' 
                          : labelController.text,
                    ));
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    }
  }

  void _deleteAlarm(String id) {
    setState(() {
      _alarms.removeWhere((alarm) => alarm.id == id);
    });
  }

  void _toggleAlarm(String id) {
    setState(() {
      final alarm = _alarms.firstWhere((a) => a.id == id);
      alarm.isActive = !alarm.isActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Simple Alarm'),
        centerTitle: true,
      ),
      body: _alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.alarm_add,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No alarms set',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap + to add an alarm',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _alarms.length,
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.alarm,
                      color: alarm.isActive ? Colors.blue : Colors.grey,
                      size: 40,
                    ),
                    title: Text(
                      alarm.time.format(context),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: alarm.isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      alarm.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: alarm.isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: alarm.isActive,
                          onChanged: (value) => _toggleAlarm(alarm.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAlarm(alarm.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAlarm,
        tooltip: 'Add Alarm',
        child: const Icon(Icons.add),
      ),
    );
  }
}
