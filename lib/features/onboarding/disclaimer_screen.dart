import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

/// Mandatory medical disclaimer. The user must scroll and agree before entering
/// the app. The text is sourced from the bundled reference catalog.
class DisclaimerScreen extends ConsumerStatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  ConsumerState<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends ConsumerState<DisclaimerScreen> {
  final _scroll = ScrollController();
  bool _scrolledToEnd = false;
  bool _agreed = false;

  static const _fallback =
      'This app is a reminder tool only. The conditions and medicines it lists '
      'are reference information (names only) to help you record what you have '
      'been prescribed. It is NOT medical advice and does NOT include dosages. '
      'Always follow the guidance of your doctor or pharmacist. Never start, '
      'stop, or change a medication based on this app.';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.offset >= _scroll.position.maxScrollExtent - 24 && !_scrolledToEnd) {
        setState(() => _scrolledToEnd = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.maxScrollExtent <= 0) {
        setState(() => _scrolledToEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    await ref.read(servicesProvider).settings.acceptDisclaimer();
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final disclaimer = ref.read(servicesProvider).reference.disclaimer;
    final text = disclaimer.trim().isEmpty ? _fallback : disclaimer;
    final canAgree = _scrolledToEnd;
    return Scaffold(
      appBar: AppBar(title: const Text('Before you start'), automaticallyImplyLeading: false),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Important', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text(text, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: canAgree ? (v) => setState(() => _agreed = v ?? false) : null,
                    title: const Text('I understand this is not medical advice'),
                    subtitle: canAgree ? null : const Text('Scroll to the end to continue'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _agreed ? _accept : null,
                      child: const Text('Agree and continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
