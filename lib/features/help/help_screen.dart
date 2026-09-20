import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/help/help_controller.dart';
import 'package:finny/models/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glossary = ref.watch(glossaryEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('help-back'),
          tooltip: 'Назад',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Финансовые термины'),
      ),
      body: SafeArea(
        child: glossary.when(
          data: (entries) => entries.isEmpty
              ? const _EmptyGlossary()
              : _GlossaryList(entries: entries),
          error: (_, _) => _GlossaryError(
            onRetry: () => ref.invalidate(glossaryEntriesProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _GlossaryList extends StatelessWidget {
  const _GlossaryList({required this.entries});

  final List<GlossaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('glossary-list'),
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _GlossaryCard(entry: entries[index]),
          if (index != entries.length - 1)
            const SizedBox(height: AppSpacing.small),
        ],
      ],
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard({required this.entry});

  final GlossaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('glossary-entry-${entry.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.term, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.small),
            Text(
              entry.definition,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGlossary extends StatelessWidget {
  const _EmptyGlossary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('glossary-empty'),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.large),
        child: Text('Пока здесь нет терминов.', textAlign: TextAlign.center),
      ),
    );
  }
}

class _GlossaryError extends StatelessWidget {
  const _GlossaryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('glossary-error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Не получилось открыть справку.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.medium),
            FilledButton(
              key: const Key('glossary-retry'),
              onPressed: onRetry,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}
