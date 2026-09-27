import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_modal_actions.dart';
import 'package:flutter/material.dart';

class FinnySleepDialog extends StatelessWidget {
  const FinnySleepDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryLight,
            child: Icon(
              Icons.bedtime_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Финни готов отдыхать',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Завершить день и посмотреть, как всё получилось?',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FinnyModalActions.primary,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Уложить спать'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              style: FinnyModalActions.secondary,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Вернуться'),
            ),
          ),
        ],
      ),
    ),
  );
}
