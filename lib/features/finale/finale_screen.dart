import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
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
          body: FinnyFlowBackdrop(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '5 дней вместе!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        const Text(
                          'Пять дней позади — Финни вырос вместе с тобой.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.large),
                        if (pet != null)
                          Center(
                            child: FinnyPreview(
                              name: pet.name,
                              colorId: pet.colorId,
                              patternId: pet.patternId,
                              developmentStage: pet.developmentStage,
                              height: 210,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.large),
                        Text(
                          'Теперь ты умеешь',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _SkillCard(
                          Icons.assignment_rounded,
                          'Планировать бюджет',
                          'Решать заранее, куда пойдут монеты.',
                          AppColors.need,
                        ),
                        const _SkillCard(
                          Icons.favorite_rounded,
                          'Отличать Нужно от Хочу',
                          'Понимать, что важно сейчас, а что может подождать.',
                          AppColors.want,
                        ),
                        const _SkillCard(
                          Icons.savings_rounded,
                          'Копить на цель',
                          'Откладывать часть монет ради чего-то большего.',
                          AppColors.savings,
                        ),
                        const _SkillCard(
                          Icons.sync_rounded,
                          'Менять план',
                          'Подстраиваться, когда появляются неожиданные траты.',
                          AppColors.primary,
                        ),
                        const SizedBox(height: AppSpacing.large),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'История завершена — но с Финни можно играть дальше!',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Ухаживай за Финни, играй в мини-игры, покупай вещи, украшай комнату и копи на новые цели.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
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
                          FinnyFlowButton(
                            onPressed: busy ? null : () => _choose(true),
                            label: 'Продолжить с Финни',
                          ),
                          const SizedBox(height: AppSpacing.small),
                          OutlinedButton(
                            onPressed: busy ? null : () => _choose(false),
                            child: const Text('Вернуться позже'),
                          ),
                        ],
                      ],
                    ),
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

class _SkillCard extends StatelessWidget {
  const _SkillCard(this.icon, this.title, this.description, this.color);
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      border: Border.all(color: Colors.white, width: 2),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
        body: FinnyFlowBackdrop(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'История завершена',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 34,
                              color: AppColors.primary,
                            ),
                            if (snapshot.data != null) ...[
                              const SizedBox(height: 8),
                              FinnyPreview(
                                name: snapshot.data!.name,
                                colorId: snapshot.data!.colorId,
                                patternId: snapshot.data!.patternId,
                                developmentStage:
                                    snapshot.data!.developmentStage,
                                height: 210,
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Text(
                              'Все 5 дней пройдены. Финни вырос, а ваш прогресс сохранён.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      if (error != null) ...[
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.small),
                      ],
                      FinnyFlowButton(
                        label: 'Продолжить с Финни',
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
                      ),
                      const SizedBox(height: AppSpacing.small),
                      OutlinedButton(
                        onPressed: () => context.go('/finale?mode=recap'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Посмотреть итоги'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
