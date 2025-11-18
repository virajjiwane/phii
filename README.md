# ⏰ Phii

**Gemini powered grouped alarms, smooth animations, and everything nice — Phii, a modern Flutter-based alarm app built for precision, calm, and control.**

[![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Gemini AI](https://img.shields.io/badge/Gemini_AI-Powered-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Hive](https://img.shields.io/badge/Hive-Local_DB-FFA000?style=for-the-badge&logo=hive&logoColor=white)](https://docs.hivedb.dev/)
[![Material 3](https://img.shields.io/badge/Material_3-Design-757575?style=for-the-badge&logo=material-design&logoColor=white)](https://m3.material.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

## ✨ Features

- **🎙️ Voice Commands**: Control alarms with natural voice commands powered by Gemini AI
- **📁 Grouped Alarms**: Organize alarms into profiles (work, weekend, gym, etc.)
- **🎨 Beautiful UI**: Smooth animations and modern Material 3 design
- **⏱️ Flexible Scheduling**: Set alarms at specific times or durations from now
- **🔔 Ring Testing**: Test your alarm sounds instantly
- **🗣️ Text-to-Speech**: Get audio feedback for your commands
- **🌙 Dark Mode**: Full theme support for day and night

## 🎤 Voice Commands

Phii supports natural voice commands including:

- "Set alarm for 7 AM"
- "Wake me up in 30 minutes"
- "Stop all alarms"
- "Create profile work"
- "Ring now"
- "Show my alarms"
- "Delete all profiles"

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio / Xcode for mobile development
- Gemini API key for voice command processing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/virajjiwane/phii.git
cd phii
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## 🏗️ Architecture

Phii follows a clean architecture with separation of concerns:

- **Services**: Business logic for alarms, profiles, and commands
  - `AlarmService`: Alarm CRUD operations
  - `ProfileService`: Profile management
  - `CommandHandlerService`: Voice command execution
  - `SpeechService`: Speech recognition
  - `GeminiSpeechService`: AI-powered command parsing

- **Models**: Data structures (Profile, SpeechCommand)
- **Screens**: UI components (HomeScreen, ProfileScreen, EditAlarmScreen)
- **Widgets**: Reusable UI components

## 🛠️ Built With

- [Flutter](https://flutter.dev/) - UI framework
- [Hive](https://docs.hivedb.dev/) - Local database
- [Alarm Package](https://pub.dev/packages/alarm) - Alarm scheduling
- [Speech to Text](https://pub.dev/packages/speech_to_text) - Voice recognition
- [Google Fonts](https://pub.dev/packages/google_fonts) - Typography
- [Gemini AI](https://ai.google.dev/) - Natural language processing

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Viraj Jiwane**
- GitHub: [@virajjiwane](https://github.com/virajjiwane)
