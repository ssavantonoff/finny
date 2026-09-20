import 'package:finny/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the required child glossary terms from JSON content', () async {
    final glossary = await AssetContentRepository().loadGlossary();

    expect(glossary, hasLength(9));
    expect(
      glossary.map((entry) => entry.term).toList(growable: false),
      const [
        'Доход',
        'Расход',
        'Обязательная покупка',
        'Необязательная покупка',
        'Накопления',
        'Финансовая цель',
        'Бюджет',
        'План',
        'Факт',
      ],
    );
    expect(glossary.map((entry) => entry.id).toSet(), hasLength(glossary.length));
    expect(
      glossary.every((entry) => entry.definition.trim().isNotEmpty),
      isTrue,
    );
  });
}
