import 'package:hive/hive.dart';

part 'profile.g.dart';

// Defines a Alarm Profile model for Hive database storage.
// Each profile has a unique ID, a name, and a list of associated alarm IDs.

@HiveType(typeId: 0)
class Profile extends HiveObject {
  @HiveField(0)
  String id; // Unique identifier for the profile

  @HiveField(1)
  String name; // Name of the profile

  @HiveField(2)
  List<int> alarmIds; // List of associated alarm IDs

  Profile({
    required this.id,
    required this.name,
    required this.alarmIds,
  });
}