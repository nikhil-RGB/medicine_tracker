import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Reminders'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Enable notifications'),
            subtitle: const Text('Allow a reminder when a dose is due'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted =
                  await ref.read(dataProvider.notifier).requestNotificationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'Notifications enabled'
                      : 'Permission not granted — check your system settings'),
                ));
              }
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('How reminders work'),
            subtitle: Text(
              'Reminders are scheduled up to 14 days ahead and refresh whenever you '
              'open the app. Overdue doses always appear in Today even if a reminder '
              'is missed, so nothing is lost.',
            ),
          ),
          const Divider(),
          const _SectionHeader('Safety'),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('Medical disclaimer'),
            subtitle: const Text('Reference data is names only, not medical advice'),
            onTap: () {
              final text = services.reference.disclaimer.trim().isEmpty
                  ? 'The conditions and medicines listed are reference information '
                      '(names only) and are not medical advice. Always follow your '
                      'doctor or pharmacist.'
                  : services.reference.disclaimer;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Medical disclaimer'),
                  content: SingleChildScrollView(child: Text(text)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.medication),
            title: Text('Medicine Reminders'),
            subtitle: Text('Local, offline medication tracking. Your data stays on this device.'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}
