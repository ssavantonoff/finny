import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/help/help_screen.dart';
import 'package:finny/features/settings/settings_screen.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _GlossaryRepository extends AssetContentRepository {
  _GlossaryRepository({this.entries = const [], this.error});

  final List<GlossaryEntry> entries;
  final Object? error;

  @override
  Future<List<GlossaryEntry>> loadGlossary() async {
    if (error != null) throw error!;
    return entries;
  }
}

const _entries = [
  GlossaryEntry(
    id: 'income',
    term: 'Доход',
    definition: 'Деньги, которые ты получаешь.',
  ),
  GlossaryEntry(
    id: 'budget',
    term: 'Бюджет',
    definition: 'План денег: сколько потратить и сколько отложить.',
  ),
];

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  ContentRepository repository, {
  String initialLocation = '/help',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [contentRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('renders glossary terms at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = await _pumpApp(
        tester,
        _GlossaryRepository(entries: _entries),
      );
      addTearDown(router.dispose);

      expect(find.byKey(const Key('glossary-list')), findsOneWidget);
      expect(find.text('Доход'), findsOneWidget);
      expect(find.text('Деньги, которые ты получаешь.'), findsOneWidget);
      expect(find.text('Бюджет'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opens help from settings and returns back', (tester) async {
    final router = await _pumpApp(
      tester,
      _GlossaryRepository(entries: _entries),
      initialLocation: '/settings',
    );
    addTearDown(router.dispose);

    expect(find.byKey(const Key('settings-help')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-help')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('glossary-list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('help-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-help')), findsOneWidget);
  });

  testWidgets('shows an empty state when glossary has no entries', (
    tester,
  ) async {
    final router = await _pumpApp(tester, _GlossaryRepository());
    addTearDown(router.dispose);

    expect(find.byKey(const Key('glossary-empty')), findsOneWidget);
    expect(find.text('Пока здесь нет терминов.'), findsOneWidget);
  });

  testWidgets('shows a retryable error state when content loading fails', (
    tester,
  ) async {
    final router = await _pumpApp(
      tester,
      _GlossaryRepository(error: StateError('broken content')),
    );
    addTearDown(router.dispose);

    expect(find.byKey(const Key('glossary-error')), findsOneWidget);
    expect(find.text('Не получилось открыть справку.'), findsOneWidget);
    expect(find.byKey(const Key('glossary-retry')), findsOneWidget);
  });
}
