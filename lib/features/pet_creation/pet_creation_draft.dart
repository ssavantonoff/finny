class PetCreationDraft {
  const PetCreationDraft({
    this.name = '',
    this.colorId = 'purple',
    this.patternId = 'plain',
  });

  static const colorIds = ['purple', 'blue', 'mint'];
  static const patternIds = ['plain', 'spots', 'stripes'];

  final String name;
  final String colorId;
  final String patternId;

  String get trimmedName => name.trim();
  bool get canSave => trimmedName.isNotEmpty && trimmedName.runes.length <= 20;

  String? get nameError {
    if (trimmedName.isEmpty) return 'Придумай имя для Финни';
    if (trimmedName.runes.length > 20) {
      return 'Имя должно быть не длиннее 20 символов';
    }
    return null;
  }

  PetCreationDraft copyWith({
    String? name,
    String? colorId,
    String? patternId,
  }) {
    assert(colorId == null || colorIds.contains(colorId));
    assert(patternId == null || patternIds.contains(patternId));
    return PetCreationDraft(
      name: name ?? this.name,
      colorId: colorId ?? this.colorId,
      patternId: patternId ?? this.patternId,
    );
  }
}
