import 'package:finny/app/providers.dart';
import 'package:finny/models/content_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final glossaryEntriesProvider = FutureProvider<List<GlossaryEntry>>((ref) {
  return ref.watch(contentRepositoryProvider).loadGlossary();
});
