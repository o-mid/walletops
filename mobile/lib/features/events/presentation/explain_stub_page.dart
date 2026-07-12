import 'package:flutter/material.dart';

/// Phase 9 will call /v1/ai/summarize. This is the entry landing only.
class ExplainStubPage extends StatelessWidget {
  const ExplainStubPage({super.key, required this.eventIds});

  final List<String> eventIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explain')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected ${eventIds.length} event(s)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...eventIds.map((id) => Text(id)),
            const SizedBox(height: 24),
            const Text('AI summary UI ships in the next phase.'),
          ],
        ),
      ),
    );
  }
}
