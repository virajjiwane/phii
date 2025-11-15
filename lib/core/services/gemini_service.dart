import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:logging/logging.dart';
import '../../models/speech_command.dart';

const API_KEY = "AIzaSyBA8cyQEDIffw_08ld5Y-Z4secmHCkoTlA";

class GeminiSpeechService {
  static final _log = Logger('GeminiSpeechService');
  late Gemini _gemini;

  bool initialize() { 
    Gemini.init(apiKey: API_KEY, enableDebugging: true);
    _gemini = Gemini.instance;
    return true;
  }

  /// Parse speech text into a structured command using Gemini
  Future<ParsedSpeechCommand> parseSpeechCommand(String speechText) async {
    _log.info('Starting to parse speech command: "$speechText"');
    try {
      final prompt = _buildPrompt(speechText);
      _log.fine('Built prompt for Gemini API');

      final response = await _gemini.text(prompt);
      _log.fine('Received response from Gemini API');

      if (response?.output == null) {
        _log.warning('No response from Gemini');
        return ParsedSpeechCommand(
          command: SpeechCommand.unknown,
          parameters: {},
          originalText: speechText,
          confidence: 0.0,
        );
      }

      _log.fine('Raw Gemini response: ${response!.output}');

      // Parse the JSON response
      final jsonResponse = _extractJson(response.output!);
      _log.fine('Extracted JSON: $jsonResponse');

      final parsed = ParsedSpeechCommand.fromJson(jsonResponse);

      _log.info(
          'Parsed command: ${parsed.command}, params: ${parsed.parameters}, confidence: ${parsed.confidence}');
      return parsed;
    } catch (e, stackTrace) {
      _log.severe('Error parsing speech command', e, stackTrace);
      return ParsedSpeechCommand(
        command: SpeechCommand.unknown,
        parameters: {},
        originalText: speechText,
        confidence: 0.0,
      );
    }
  }

  String _buildPrompt(String speechText) {
    _log.fine('Building prompt for speech text: "$speechText"');
    // Build a dynamic list of commands with examples
    final commandsInfo = SpeechCommand.values
        .where((cmd) => cmd != SpeechCommand.unknown)
        .map((cmd) => '''
- ${cmd.commandKey}: ${cmd.description}
  Examples: ${cmd.examples.take(3).map((e) => '"$e"').join(", ")}''')
        .join('\n');

    return '''
You are a voice command parser for an alarm app called Phii. Parse the user's voice command into a structured format.

Available commands:
$commandsInfo

User said: "$speechText"

Respond ONLY with valid JSON in this format:
{
  "command": "command_key_here",
  "parameters": {
    "hour": 7,
    "minute": 30,
    "period": "AM",
    "duration_minutes": 30,
    "profile_name": "weekday"
  },
  "confidence": 0.95,
  "originalText": "$speechText"
}

Parameter extraction rules:
- For create_alarm: Extract hour (1-12), minute (0-59), period ("AM"/"PM")
  * If no period specified, infer from context (e.g., "7" alone = 7 AM if morning context)
  * Support 24-hour format (e.g., "14:00" = 2 PM)
- For create_alarm_in: Extract duration_minutes (total minutes from now)
  * Parse "30 minutes", "2 hours", "1 hour 15 minutes"
  * Convert all to total minutes
- For create_profile: Extract profile_name (string)
  * Clean up the name (e.g., "profile work" → "work")

If the command is unclear or ambiguous, use "unknown" and set confidence to 0.0.
Be flexible with phrasing - understand natural variations.
''';
  }

  Map<String, dynamic> _extractJson(String response) {
    try {
      // Remove markdown code blocks if present
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      return json.decode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      _log.severe('Failed to parse JSON from Gemini response: $response', e);
      return {
        'command': 'unknown',
        'parameters': {},
        'confidence': 0.0,
        'originalText': '',
      };
    }
  }

  /// Get a natural language response for feedback
  Future<String> getCommandFeedback(ParsedSpeechCommand command) async {
    try {
      final prompt = '''
Generate a brief, friendly confirmation message for this voice command:

Command: ${command.command.toString().split('.').last}
Parameters: ${command.parameters}
Original text: "${command.originalText}"

Respond with ONLY the confirmation message, no explanation. Keep it under 15 words.
Examples:
- "Setting your alarm for 7:30 AM"
- "Alarm will ring in 30 minutes"
- "Stopping all alarms now"
''';

      final response = await _gemini.text(prompt);
      return response?.output?.trim() ?? 'Command received';
    } catch (e) {
      _log.warning('Failed to get feedback', e);
      return 'Command received';
    }
  }
}
