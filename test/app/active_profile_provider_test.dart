import 'package:finny/app/providers.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  test('has no active profile before app-level initialization', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeProfileIdProvider), isNull);
  });

  test(
    'exposes the selected profile ID without changing profile data',
    () async {
      final database = createTestDatabase();
      final profiles = SqliteProfileRepository(database);
      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final normal = await profiles.create(
        Profile(
          gameName: 'Обычная игра',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final demo = await profiles.create(
        Profile(
          gameName: 'Демо',
          profileType: ProfileType.demo,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );
      final controller = container.read(activeProfileIdProvider.notifier);

      controller.setActiveProfileId(normal.id!);
      expect(container.read(activeProfileIdProvider), normal.id);

      controller.setActiveProfileId(demo.id!);
      expect(container.read(activeProfileIdProvider), demo.id);

      expect(
        (await profiles.findById(normal.id!))?.profileType,
        ProfileType.normal,
      );
      expect(
        (await profiles.findById(demo.id!))?.profileType,
        ProfileType.demo,
      );

      controller.clear();
      expect(container.read(activeProfileIdProvider), isNull);
    },
  );

  test('rejects IDs that cannot belong to a persisted profile', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(0),
      throwsArgumentError,
    );
    expect(container.read(activeProfileIdProvider), isNull);
  });
}
