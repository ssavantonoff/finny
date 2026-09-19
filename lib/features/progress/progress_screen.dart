import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({this.completedDay, super.key});

  final int? completedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(activeProfileIdProvider);
    final stage = completedDay == 5 ? 3 : 2;
    return Scaffold(
      appBar: AppBar(title: const Text('Рост Финни')),
      body: SafeArea(
        child: FutureBuilder<Pet?>(
          future: profileId == null
              ? Future<Pet?>.value()
              : ref.read(gameRepositoryProvider).getPet(profileId),
          builder: (context, snapshot) {
            final pet = snapshot.data;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Финни вырос!',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        'Этап $stage',
                        key: const Key('progress-stage'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      if (pet != null)
                        FinnyPreview(
                          colorId: pet.colorId,
                          patternId: pet.patternId,
                          developmentStage: pet.developmentStage,
                        )
                      else if (snapshot.connectionState != ConnectionState.done)
                        const CircularProgressIndicator(),
                      if (completedDay == 5) ...[
                        const SizedBox(height: AppSpacing.large),
                        const Text(
                          'Ты прошёл все пять дней с Финни.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.large),
                      FilledButton(
                        key: const Key('progress-home'),
                        onPressed: () => context.go('/home'),
                        child: const Text('На главную'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
