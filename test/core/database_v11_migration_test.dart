import 'dart:convert';
import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'v10 to v11 normalizes unfinished Day 4 and preserves completed history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'finny_day4_v11_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final path = '${directory.path}/finny.sqlite';
      final original = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final games = SqliteGameRepository(original);
      final ids = <String, (int, int)>{};

      Future<(int, int)> fixture(
        String name,
        String status,
        List<String> resolved,
      ) async {
        final profileId = await (await original.database).insert('profiles', {
          'game_name': name,
          'profile_type': 'NORMAL',
          'onboarding_completed': 1,
          'created_at': DateTime.utc(2026).toIso8601String(),
        });
        await games.ensureInitialState(profileId);
        await games.savePet(
          Pet(
            profileId: profileId,
            name: 'Финни',
            colorId: 'blue',
            patternId: 'plain',
            developmentStage: 1,
            growthPoints: 0,
            satiety: 80,
            care: 80,
            mood: 80,
          ),
        );
        final period = await games.startPeriod(
          profileId: profileId,
          definitionId: 'period_4_discount',
          periodNumber: 4,
          baseIncome: 500,
          requiredCheckpoints: const [
            'financial_task',
            'savings_decision',
            'discount_decision',
          ],
          createdAt: DateTime.utc(2026, 1, 4),
        );
        if (status != 'planning') {
          await confirmBudgetForTest(
            games,
            profileId: profileId,
            periodId: period.id!,
          );
        }
        await (await original.database).update(
          'game_periods',
          {'status': status, 'resolved_checkpoints': jsonEncode(resolved)},
          where: 'id = ?',
          whereArgs: [period.id],
        );
        ids[name] = (profileId, period.id!);
        return (profileId, period.id!);
      }

      await fixture('planning', 'planning', []);
      await fixture('all-resolved', 'active', [
        'financial_task',
        'savings_decision',
        'discount_decision',
      ]);
      await fixture('one-remains', 'active', [
        'financial_task',
        'discount_decision',
      ]);
      await fixture('already-ready', 'readyToFinish', [
        'financial_task',
        'savings_decision',
        'discount_decision',
      ]);
      await fixture('historical', 'completed', [
        'financial_task',
        'savings_decision',
        'discount_decision',
      ]);
      final (legacyProfile, legacyPeriod) = await fixture(
        'legacy-task',
        'active',
        ['financial_task', 'discount_decision'],
      );
      final (skipProfile, skipPeriod) = await fixture('skipped', 'active', []);
      final (boughtProfile, boughtPeriod) = await fixture(
        'purchased',
        'active',
        [],
      );

      final db = await original.database;
      await db.insert('task_progress', {
        'profile_id': legacyProfile,
        'task_id': 'task_discount_04',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': jsonEncode({'answerId': 'consider'}),
        'updated_at': DateTime.utc(2026, 1, 4).toIso8601String(),
      });
      await db.insert('transactions', {
        'profile_id': legacyProfile,
        'period_id': legacyPeriod,
        'type': 'task_reward',
        'amount': 50,
        'source': 'task_reward_task_discount_04',
        'description': 'Старая награда',
        'created_at': DateTime.utc(2026, 1, 4).toIso8601String(),
        'deduplication_key': 'task_reward_${legacyPeriod}_task_discount_04',
      });
      await db.update(
        'game_states',
        {'wallet_balance': 550},
        where: 'profile_id = ?',
        whereArgs: [legacyProfile],
      );
      for (final (profileId, periodId, outcome) in [
        (skipProfile, skipPeriod, 'skipped'),
        (boughtProfile, boughtPeriod, 'purchased'),
      ]) {
        await db.insert('period_special_actions', {
          'profile_id': profileId,
          'period_id': periodId,
          'action_id': 'day4_treat_discount',
          'outcome': outcome,
          'operation_id': 'old-$outcome',
          'created_at': DateTime.utc(2026, 1, 4).toIso8601String(),
        });
      }
      await db.setVersion(10);
      await original.close();

      final migrated = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(migrated.close);
      final upgraded = await migrated.database;
      expect(await upgraded.getVersion(), AppDatabase.schemaVersion);
      final migratedGames = SqliteGameRepository(migrated);
      for (final entry in ids.entries) {
        final (profileId, periodId) = entry.value;
        final period = (await migratedGames.getPeriodById(
          profileId,
          periodId,
        ))!;
        if (entry.key == 'historical') {
          expect(period.requiredCheckpoints, contains('discount_decision'));
          expect(period.resolvedCheckpoints, contains('discount_decision'));
        } else {
          expect(period.requiredCheckpoints, [
            'financial_task',
            'savings_decision',
          ]);
          expect(
            period.resolvedCheckpoints,
            isNot(contains('discount_decision')),
          );
        }
        expect(period.status.name, switch (entry.key) {
          'planning' => 'planning',
          'all-resolved' => 'readyToFinish',
          'already-ready' => 'readyToFinish',
          'historical' => 'completed',
          _ => 'active',
        });
      }
      final progress = await migratedGames.getTaskProgress(
        legacyProfile,
        'task_shopping_trip_04',
      );
      expect(progress?.scenarioState, {
        'type': 'legacy_day4_discount',
        'legacyTaskId': 'task_discount_04',
      });
      expect(
        await migratedGames.getTaskProgress(legacyProfile, 'task_discount_04'),
        isNull,
      );
      final rewards = (await migratedGames.getTransactions(legacyProfile))
          .where((row) => row.type == 'task_reward')
          .toList();
      expect(rewards, hasLength(1));
      expect(
        (
          rewards.single.amount,
          rewards.single.source,
          rewards.single.deduplicationKey,
        ),
        (
          50,
          'task_reward_task_shopping_trip_04',
          'task_reward_${legacyPeriod}_task_shopping_trip_04',
        ),
      );
      expect(
        (await migratedGames.getGameState(legacyProfile))!.walletBalance,
        550,
      );
      final canonical = (await AssetContentRepository().loadTasks())
          .singleWhere((task) => task.id == 'task_shopping_trip_04');
      final replay =
          await SqliteTaskCompletionPort(migrated)
                  .submitFinancialTaskShoppingTrip(
                    profileId: legacyProfile,
                    periodId: legacyPeriod,
                    task: canonical,
                    selections: const {
                      'water': ShoppingTripSelection(
                        priceScenarioId: 'small_better',
                        smallQuantity: 2,
                        largeQuantity: 0,
                      ),
                      'soap': ShoppingTripSelection(
                        priceScenarioId: 'large_better',
                        smallQuantity: 0,
                        largeQuantity: 1,
                      ),
                      'cookies': ShoppingTripSelection(
                        priceScenarioId: 'large_better',
                        smallQuantity: 0,
                        largeQuantity: 1,
                      ),
                    },
                  )
              as TaskAnswerCompleted;
      expect(replay.wasAlreadyCompleted, isTrue);
      expect(replay.rewardAppliedNow, isFalse);
      expect(replay.period.dayProgress, 10);
      expect(
        (await migratedGames.getGameState(legacyProfile))!.walletBalance,
        550,
      );
      final promotionPort = SqliteSpecialPurchasePort(migrated);
      expect(
        await promotionPort.hasPurchasedPromotion(
          profileId: skipProfile,
          periodId: skipPeriod,
          promotionId: 'day4_treat_discount',
        ),
        isFalse,
      );
      expect(
        await upgraded.query(
          'period_special_actions',
          where: 'profile_id = ?',
          whereArgs: [skipProfile],
        ),
        isEmpty,
      );
      expect(
        await promotionPort.hasPurchasedPromotion(
          profileId: boughtProfile,
          periodId: boughtPeriod,
          promotionId: 'day4_treat_discount',
        ),
        isTrue,
      );
    },
  );
}
