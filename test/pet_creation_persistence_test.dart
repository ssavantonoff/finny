import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  test('SQLite restores Pet and isolates NORMAL from DEMO', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = SqliteProfileRepository(database);
    final games = SqliteGameRepository(database);
    final normal = await profiles.create(
      Profile(
        gameName: 'Игрок',
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
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(await games.getPet(normal.id!), isNull);
    await games.savePet(
      Pet(
        profileId: normal.id!,
        name: 'Пушок',
        colorId: 'mint',
        patternId: 'stripes',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 100,
        care: 100,
        mood: 100,
      ),
    );
    await games.savePet(
      Pet(
        profileId: demo.id!,
        name: 'Демо Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 4,
        growthPoints: 81,
        satiety: 52,
        care: 56,
        mood: 61,
      ),
    );

    final saved = await games.getPet(normal.id!);
    expect(saved?.name, 'Пушок');
    expect(saved?.colorId, 'mint');
    expect(saved?.patternId, 'stripes');
    expect(saved?.developmentStage, 0);
    expect(saved?.growthPoints, 0);
    expect(saved?.satiety, 100);
    expect(saved?.care, 100);
    expect(saved?.mood, 100);
    expect((await games.getPet(demo.id!))?.name, 'Демо Финни');

    await games.savePet(
      saved!.copyWith(name: 'Новое имя', colorId: 'purple', patternId: 'spots'),
    );
    final updated = await games.getPet(normal.id!);
    expect(updated?.name, 'Новое имя');
    expect(updated?.colorId, 'purple');
    expect(updated?.patternId, 'spots');
    expect(updated?.satiety, 100);
    expect(updated?.care, 100);
    expect((await games.getPet(demo.id!))?.growthPoints, 81);
  });
}
