import 'package:finny/features/pet_creation/pet_creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial appearance is blue and plain', () {
    const draft = PetCreationDraft();
    expect(draft.colorId, 'blue');
    expect(draft.patternId, 'plain');
    expect(draft.canSave, isFalse);
  });

  test('name is trimmed and must contain 1 to 20 characters', () {
    expect(const PetCreationDraft(name: '').canSave, isFalse);
    expect(const PetCreationDraft(name: '   ').canSave, isFalse);
    const valid = PetCreationDraft(name: '  Финни  ');
    expect(valid.canSave, isTrue);
    expect(valid.trimmedName, 'Финни');
    expect(PetCreationDraft(name: 'a' * 20).canSave, isTrue);
    expect(PetCreationDraft(name: 'a' * 21).canSave, isFalse);
  });

  test('color and pattern selections update independent state', () {
    const initial = PetCreationDraft();
    final selected = initial.copyWith(colorId: 'mint', patternId: 'stripes');
    expect(initial.colorId, 'blue');
    expect(initial.patternId, 'plain');
    expect(selected.colorId, 'mint');
    expect(selected.patternId, 'stripes');
    expect(PetCreationDraft.colorIds, ['blue', 'purple', 'mint']);
    expect(PetCreationDraft.patternIds, ['plain', 'spots', 'stripes']);
  });
}
