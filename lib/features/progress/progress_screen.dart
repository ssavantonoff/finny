import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
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
      body: FinnyFlowBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Финни вырос!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 3; i++) ...[
                        if (i > 1)
                          Container(
                            width: 36,
                            height: 3,
                            color: i <= stage
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: i <= stage
                              ? AppColors.primary
                              : AppColors.primaryLight,
                          child: Text(
                            '$i',
                            style: TextStyle(
                              color: i <= stage
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Этап $stage из 3',
                    key: const Key('progress-stage'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (profileId != null)
                    CurrentFinnyArt(profileId: profileId, height: 285),
                  const SizedBox(height: 12),
                  const Text(
                    'Твои решения за несколько дней помогли Финни вырасти.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FinnyFlowButton(
                    key: const Key('progress-home'),
                    label: completedDay == 5
                        ? 'Посмотреть итоги'
                        : 'Продолжить',
                    onPressed: () =>
                        context.go(completedDay == 5 ? '/finale' : '/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
