class PeriodDefinition {
  const PeriodDefinition({
    required this.id,
    required this.number,
    required this.title,
    required this.baseIncome,
  });

  final String id;
  final int number;
  final String title;
  final int baseIncome;

  factory PeriodDefinition.fromJson(Map<String, Object?> json) =>
      PeriodDefinition(
        id: json['id'] as String,
        number: json['number'] as int,
        title: json['title'] as String,
        baseIncome: json['baseIncome'] as int,
      );
}

class GlossaryEntry {
  const GlossaryEntry({
    required this.id,
    required this.term,
    required this.definition,
  });

  final String id;
  final String term;
  final String definition;

  factory GlossaryEntry.fromJson(Map<String, Object?> json) => GlossaryEntry(
    id: json['id'] as String,
    term: json['term'] as String,
    definition: json['definition'] as String,
  );
}
