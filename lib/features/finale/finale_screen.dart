import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FinaleScreen extends ConsumerStatefulWidget {
  const FinaleScreen({super.key});

  @override
  ConsumerState<FinaleScreen> createState() => _FinaleScreenState();
}

class _FinaleScreenState extends ConsumerState<FinaleScreen> {
  bool busy = false;
  String? error;

  Future<void> _choose(bool play) async {
    if (busy) return;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final lifecycle = ref.read(campaignLifecycleServiceProvider);
      if (play) {
        await lifecycle.startFreePlay(profileId);
      } else {
        await lifecycle.finishStory(profileId);
      }
      if (mounted) context.go(play ? '/home' : '/campaign-complete');
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось сохранить выбор. Попробуй ещё раз.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    if (profileId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder(
      future: Future.wait<Object?>([
        ref.read(campaignLifecycleServiceProvider).load(profileId),
        ref.read(gameRepositoryProvider).getPet(profileId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Не удалось загрузить итоги. Попробуй открыть экран ещё раз.',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final lifecycle = snapshot.data![0] as CampaignLifecycleSnapshot;
        final pet = snapshot.data![1] as Pet?;
        if (!lifecycle.campaignCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/home');
          });
          return const SizedBox.shrink();
        }
        final recap = lifecycle.mode != CampaignMode.finalePending;
        return Scaffold(
          appBar: AppBar(title: const Text('Итоги истории')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '5 дней вместе!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      const Text(
                        'Ты прошёл всю историю с Финни и помог ему стать взрослее.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      if (pet != null)
                        Center(
                          child: FinnyPreview(
                            colorId: pet.colorId,
                            patternId: pet.patternId,
                            developmentStage: pet.developmentStage,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.large),
                      Text(
                        'Теперь ты умеешь',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const ListTile(
                        title: Text('Планировать бюджет'),
                        subtitle: Text('Решать заранее, куда пойдут деньги.'),
                      ),
                      const ListTile(
                        title: Text('Отличать нужное от желаний'),
                        subtitle: Text(
                          'Понимать, что важно сейчас, а что может подождать.',
                        ),
                      ),
                      const ListTile(
                        title: Text('Копить на цель'),
                        subtitle: Text(
                          'Откладывать часть денег ради чего-то большего.',
                        ),
                      ),
                      const ListTile(
                        title: Text('Менять план'),
                        subtitle: Text(
                          'Подстраиваться, когда появляются неожиданные траты.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      if (error != null) ...[
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.small),
                      ],
                      if (recap)
                        FilledButton(
                          onPressed: () => context.go(
                            lifecycle.mode == CampaignMode.freePlay
                                ? '/home'
                                : '/campaign-complete',
                          ),
                          child: Text(
                            lifecycle.mode == CampaignMode.freePlay
                                ? 'Вернуться к Финни'
                                : 'Назад',
                          ),
                        )
                      else ...[
                        FilledButton(
                          onPressed: busy ? null : () => _choose(true),
                          child: const Text('Продолжить с Финни'),
                        ),
                        const Text(
                          'Играй, копи на цели и украшай дом.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        OutlinedButton(
                          onPressed: busy ? null : () => _choose(false),
                          child: const Text('Завершить историю'),
                        ),
                        const Text(
                          'Продолжить играть можно будет позже.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CampaignCompleteScreen extends ConsumerStatefulWidget {
  const CampaignCompleteScreen({super.key});
  @override
  ConsumerState<CampaignCompleteScreen> createState() =>
      _CampaignCompleteScreenState();
}

class _CampaignCompleteScreenState
    extends ConsumerState<CampaignCompleteScreen> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    if (profileId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder(
      future: ref.read(gameRepositoryProvider).getPet(profileId),
      builder: (context, snapshot) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (snapshot.data != null)
                      FinnyPreview(
                        colorId: snapshot.data!.colorId,
                        patternId: snapshot.data!.patternId,
                        developmentStage: snapshot.data!.developmentStage,
                      ),
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      'История завершена',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    const Text(
                      'Все 5 дней пройдены.\nФинни вырос, а всё, что вы собрали вместе, сохранено.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    const Text('Спасибо за игру!'),
                    const SizedBox(height: AppSpacing.large),
                    if (error != null) ...[
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.small),
                    ],
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() {
                                busy = true;
                                error = null;
                              });
                              try {
                                await ref
                                    .read(campaignLifecycleServiceProvider)
                                    .startFreePlay(profileId);
                                if (context.mounted) context.go('/home');
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => error = 'Не удалось продолжить игру. Попробуй ещё раз.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: const Text('Продолжить играть'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/finale?mode=recap'),
                      child: const Text('Посмотреть итоги'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
