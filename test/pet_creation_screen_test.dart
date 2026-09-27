import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/features/pet_creation/pet_creation_screen.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_database.dart';

class _TestActiveProfileController extends ActiveProfileIdController {
  _TestActiveProfileController(this.initialId);

  final int? initialId;

  @override
  int? build() => initialId;
}

class _TestGameRepository extends SqliteGameRepository {
  _TestGameRepository(super.database);

  final pets = <int, Pet>{};
  bool failRead = false;
  bool failSave = false;
  int reads = 0;
  int saves = 0;

  @override
  Future<Pet?> getPet(int profileId) async {
    reads++;
    if (failRead) throw StateError('read failure');
    return pets[profileId];
  }

  @override
  Future<void> savePet(Pet pet) async {
    saves++;
    if (failSave) throw StateError('save failure');
    pets[pet.profileId] = pet;
  }
}

Future<ProviderContainer> _pumpPetCreation(
  WidgetTester tester,
  _TestGameRepository repository,
  int? profileId,
) async {
  final container = ProviderContainer(
    overrides: [
      gameRepositoryProvider.overrideWithValue(repository),
      activeProfileIdProvider.overrideWith(
        () => _TestActiveProfileController(profileId),
      ),
    ],
  );
  final router = GoRouter(
    initialLocation: '/pet-creation',
    routes: [
      GoRoute(
        path: '/pet-creation',
        builder: (_, _) => const PetCreationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Домашний экран')),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapChoice(WidgetTester tester, String id) async {
  final finder = find.byKey(Key('pet-choice-$id'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Map<String, Rect> _choiceRects(WidgetTester tester, List<String> ids) => {
  for (final id in ids)
    id: () {
      final choice = find.byKey(Key('pet-choice-$id'));
      final row = find.ancestor(of: choice, matching: find.byType(Row)).first;
      return tester.getRect(choice).shift(-tester.getTopLeft(row));
    }(),
};

Future<void> _save(WidgetTester tester) async {
  final finder = find.widgetWithText(FilledButton, 'Создать Финни');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase database;
  late _TestGameRepository repository;

  setUp(() {
    database = createTestDatabase();
    repository = _TestGameRepository(database);
  });
  tearDown(() => database.close());

  testWidgets('null active profile keeps form and never saves', (tester) async {
    await _pumpPetCreation(tester, repository, null);
    await tester.enterText(find.byType(TextField), '  Мой Финни  ');
    await tester.pumpAndSettle();

    expect(find.textContaining('Сначала открой свой профиль'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.reads, 0);
    expect(repository.saves, 0);
    expect(find.text('  Мой Финни  '), findsOneWidget);
  });

  testWidgets('selection keeps every color and pattern in place at 360dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPetCreation(tester, repository, null);

    const colorIds = ['blue', 'purple', 'mint'];
    const patternIds = ['plain', 'spots', 'stripes'];
    final initialColors = _choiceRects(tester, colorIds);
    final initialPatterns = _choiceRects(tester, patternIds);

    for (final selected in ['blue', 'purple', 'mint', 'blue']) {
      await _tapChoice(tester, selected);
      expect(_choiceRects(tester, colorIds), initialColors);
      expect(_choiceRects(tester, patternIds), initialPatterns);
      expect(
        tester.widget<FinnyPreview>(find.byType(FinnyPreview)).colorId,
        selected,
      );
      expect(tester.takeException(), isNull);
    }
    for (final selected in ['plain', 'spots', 'stripes', 'plain']) {
      await _tapChoice(tester, selected);
      expect(_choiceRects(tester, colorIds), initialColors);
      expect(_choiceRects(tester, patternIds), initialPatterns);
      expect(
        tester.widget<FinnyPreview>(find.byType(FinnyPreview)).patternId,
        selected,
      );
      expect(tester.takeException(), isNull);
    }
    expect(
      tester
          .widget<PetAppearanceOption>(find.byKey(const Key('pet-choice-blue')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<PetAppearanceOption>(
            find.byKey(const Key('pet-choice-purple')),
          )
          .selected,
      isFalse,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
    'new Pet uses defaults, preview changes and saves via repository',
    (tester) async {
      const id = 1;
      await _pumpPetCreation(tester, repository, id);

      expect(
        tester.widget<FinnyPreview>(find.byType(FinnyPreview)).colorId,
        'purple',
      );
      expect(
        tester.widget<FinnyPreview>(find.byType(FinnyPreview)).patternId,
        'plain',
      );
      expect(
        tester
            .widget<PetAppearanceOption>(
              find.byKey(const Key('pet-choice-purple')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<PetAppearanceOption>(
              find.byKey(const Key('pet-choice-plain')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), '  Пушок  ');
      await _tapChoice(tester, 'purple');
      await _tapChoice(tester, 'spots');
      expect(
        tester.widget<FinnyPreview>(find.byType(FinnyPreview)).colorId,
        'purple',
      );
      expect(
        tester.widget<FinnyPreview>(find.byType(FinnyPreview)).patternId,
        'spots',
      );
      await _save(tester);

      expect(find.text('Домашний экран'), findsOneWidget);
      final pet = await repository.getPet(id);
      expect(pet?.name, 'Пушок');
      expect(pet?.colorId, 'purple');
      expect(pet?.patternId, 'spots');
      expect(pet?.developmentStage, 1);
      expect(pet?.growthPoints, 0);
      expect(pet?.satiety, 55);
      expect(pet?.care, 80);
      expect(pet?.mood, 80);
    },
  );

  testWidgets('load error is not treated as missing Pet', (tester) async {
    const id = 1;
    repository.failRead = true;
    await _pumpPetCreation(tester, repository, id);
    expect(
      find.textContaining('Не получилось загрузить Финни'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Финни');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.saves, 0);
  });

  testWidgets('save error preserves form and does not navigate', (
    tester,
  ) async {
    const id = 1;
    repository.failSave = true;
    await _pumpPetCreation(tester, repository, id);
    await tester.enterText(find.byType(TextField), 'Финни');
    await _tapChoice(tester, 'mint');
    await _save(tester);
    expect(
      find.textContaining('Не получилось сохранить Финни'),
      findsOneWidget,
    );
    expect(find.text('Домашний экран'), findsNothing);
    expect(find.text('Финни'), findsOneWidget);
    expect(
      tester.widget<FinnyPreview>(find.byType(FinnyPreview)).colorId,
      'mint',
    );
    expect(await repository.getPet(id), isNull);
  });

  testWidgets('existing Pet keeps core values and other profile isolated', (
    tester,
  ) async {
    const normalId = 1;
    const demoId = 2;
    await repository.savePet(
      Pet(
        profileId: normalId,
        name: 'Старое имя',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 3,
        growthPoints: 85,
        satiety: 42,
        care: 58,
        mood: 73,
      ),
    );
    await repository.savePet(
      Pet(
        profileId: demoId,
        name: 'Демо',
        colorId: 'mint',
        patternId: 'spots',
        developmentStage: 2,
        growthPoints: 15,
        satiety: 60,
        care: 62,
        mood: 65,
      ),
    );
    await _pumpPetCreation(tester, repository, normalId);
    expect(find.text('Старое имя'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Новое имя');
    await _tapChoice(tester, 'purple');
    await _tapChoice(tester, 'stripes');
    await _save(tester);

    final normal = await repository.getPet(normalId);
    final demo = await repository.getPet(demoId);
    expect(find.text('Домашний экран'), findsOneWidget);
    expect(normal?.name, 'Новое имя');
    expect(normal?.colorId, 'purple');
    expect(normal?.patternId, 'stripes');
    expect(normal?.developmentStage, 3);
    expect(normal?.growthPoints, 85);
    expect(normal?.satiety, 42);
    expect(normal?.care, 58);
    expect(normal?.mood, 73);
    expect(demo?.name, 'Демо');
    expect(demo?.colorId, 'mint');
    expect(demo?.patternId, 'spots');
    expect(demo?.growthPoints, 15);
  });
}
