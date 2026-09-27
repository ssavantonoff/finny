class ProfileName {
  const ProfileName(this.input);

  final String input;

  String get trimmed => input.trim();
  bool get isValid => trimmed.isNotEmpty && trimmed.runes.length <= 20;

  String? get error {
    if (trimmed.isEmpty) return 'Напиши своё имя';
    if (trimmed.runes.length > 20) {
      return 'Имя должно быть не длиннее 20 символов';
    }
    return null;
  }
}
