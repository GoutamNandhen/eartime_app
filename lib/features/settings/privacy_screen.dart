import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const sections = <(String, String)>[
    (
      'Local records',
      'EarTime stores device connection and playback-activity observations, timestamps, transport identifiers, device names, identity associations, listening intervals and preferences in app-private storage. Older local history is retained separately. These records can reveal usage habits. App storage and local archives do not have additional EarTime password encryption.',
    ),
    (
      'What is not measured',
      'EarTime does not record microphone audio. Global playback activity and connected earbuds do not prove which output receives another app\'s audio. Unknown or unverified activity is not confirmed listening time. Sound level, acoustic exposure, wearing state and separate earbud or case battery values are not claimed without validated observations.',
    ),
    (
      'Bluetooth access',
      'On Android 12 and later, Nearby devices access permits Bluetooth connection observations and supported connected-device queries. Older Android versions use the legacy Bluetooth permissions. EarTime does not request location or Bluetooth scanning permission. Permission does not prove route attribution or collector health. Denial can prevent new observations; existing history remains local.',
    ),
    (
      'Notifications and background work',
      'Notifications are optional for recorded daily and weekly summaries, which default to off. Permission, channel blocking, quiet hours and Android background restrictions can prevent or delay delivery. Foreground-service status is separate and is not silenced by summary quiet hours. Boot and time-change handling reschedules only opted-in summaries. No exact-alarm permission is requested.',
    ),
    (
      'Optional device inspection',
      'Read-only Bluetooth service-catalog inspection requires an explicit confirmation for the selected endpoint. Consent is short-lived and is not saved. It can connect to that device to enumerate service metadata; it does not read characteristic values, subscribe to notifications, pair, or send vendor control commands. This is not verified OnePlus or OPPO telemetry support.',
    ),
    (
      'Network and accounts',
      'EarTime has no account, advertising, cloud-sync or automatic analytics-upload flow. History, reports and settings work locally. Development builds include internet access for Flutter tooling; that permission is not evidence of a cloud backup service. An Android document provider chosen during export may store the selected file remotely under its own policy.',
    ),
    (
      'Export and restore limits',
      'Application exports include native observations and device associations, settings, goals, notification preferences, preserved legacy history and journal recovery metadata. They are unencrypted and integrity-checked, not password protected. Whole-app restore is not yet available. The separate native-only archive excludes settings and legacy history; confirmed native restore retains a private recovery copy and does not accept application exports. Archives can contain private device identifiers and usage habits, so their destination and sharing require care.',
    ),
    (
      'Retention and deletion',
      'EarTime does not automatically delete uncertain legacy records. Complete in-app history deletion is not implemented yet. Clearing Android app storage or uninstalling may permanently remove local records and private recovery files. Native journal exports do not protect every category of app data. Android cloud-backup and device-transfer exclusions are configured; no automatic recovery is promised.',
    ),
    (
      'Diagnostic logs',
      'Local Android diagnostics may contain device names, transport identifiers and detailed events from the existing collector. They are not automatically uploaded by EarTime. Raw logs, databases and archives should not be posted publicly. A complete collector-log privacy audit remains unfinished.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy and permissions')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final (heading, body) in sections) ...[
          Semantics(
            header: true,
            child: Text(
              heading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}
