import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/app_build_information.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('About EarTime')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ref
            .watch(appBuildInformationProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Installed version unavailable'),
                trailing: IconButton(
                  tooltip: 'Retry version information',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(appBuildInformationProvider),
                ),
              ),
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Installed version'),
                    subtitle: SelectableText(value.versionName),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Build number'),
                    subtitle: SelectableText('${value.versionCode}'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Package'),
                    subtitle: SelectableText(value.packageName),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Debugging'),
                    subtitle: Text(value.debuggable ? 'Enabled' : 'Disabled'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              showLicensePage(context: context, applicationName: 'EarTime'),
        ),
      ],
    ),
  );
}
