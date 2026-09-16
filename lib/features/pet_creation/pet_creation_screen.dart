import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/features/pet_creation/pet_creation_draft.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PetCreationScreen extends ConsumerStatefulWidget {
  const PetCreationScreen({super.key});

  @override
  ConsumerState<PetCreationScreen> createState() => _PetCreationScreenState();
}

class _PetCreationScreenState extends ConsumerState<PetCreationScreen> {
  final _nameController = TextEditingController();
  PetCreationDraft _draft = const PetCreationDraft();
  Pet? _existingPet;
  int? _loadedProfileId;
  int? _lastNonNullProfileId;
  int _loadGeneration = 0;
  bool _loading = false;
  bool _saving = false;
  bool _nameTouched = false;
  bool _loadFailed = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) _loadForProfile(ref.read(activeProfileIdProvider));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadForProfile(int? profileId) async {
    final generation = ++_loadGeneration;
    if (profileId == null) {
      setState(() {
        _loadedProfileId = null;
        _existingPet = null;
        _loading = false;
        _loadFailed = false;
        _saveFailed = false;
      });
      return;
    }

    final switchedProfile =
        _lastNonNullProfileId != null && _lastNonNullProfileId != profileId;
    _lastNonNullProfileId = profileId;
    setState(() {
      _loadedProfileId = null;
      _existingPet = null;
      _loading = true;
      _loadFailed = false;
      _saveFailed = false;
      if (switchedProfile) {
        _draft = const PetCreationDraft();
        _nameController.clear();
        _nameTouched = false;
      }
    });

    try {
      final pet = await ref.read(gameRepositoryProvider).getPet(profileId);
      if (!mounted ||
          generation != _loadGeneration ||
          ref.read(activeProfileIdProvider) != profileId) {
        return;
      }
      setState(() {
        _existingPet = pet;
        _loadedProfileId = profileId;
        _loading = false;
        if (pet != null) {
          _draft = PetCreationDraft(
            name: pet.name,
            colorId: pet.colorId,
            patternId: pet.patternId,
          );
          _nameController.text = pet.name;
        }
      });
    } catch (_) {
      if (!mounted ||
          generation != _loadGeneration ||
          ref.read(activeProfileIdProvider) != profileId) {
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _save() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (_saving ||
        _loading ||
        _loadFailed ||
        profileId == null ||
        profileId != _loadedProfileId ||
        !_draft.canSave) {
      return;
    }

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      // Reload before replacing a row so parallel core progress is not reset.
      final currentPet = await ref
          .read(gameRepositoryProvider)
          .getPet(profileId);
      if (!mounted || ref.read(activeProfileIdProvider) != profileId) return;
      if (_existingPet != null && currentPet == null) {
        throw StateError('Pet disappeared before save.');
      }
      final pet = currentPet == null
          ? Pet(
              profileId: profileId,
              name: _draft.trimmedName,
              colorId: _draft.colorId,
              patternId: _draft.patternId,
              developmentStage: 0,
              growthPoints: 0,
              satiety: 100,
              mood: 100,
            )
          : currentPet.copyWith(
              name: _draft.trimmedName,
              colorId: _draft.colorId,
              patternId: _draft.patternId,
            );
      await ref.read(gameRepositoryProvider).savePet(pet);
      if (!mounted || ref.read(activeProfileIdProvider) != profileId) return;
      context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen<int?>(activeProfileIdProvider, (_, next) {
      _loadForProfile(next);
    });
    final canSave =
        profileId != null &&
        profileId == _loadedProfileId &&
        !_loading &&
        !_saving &&
        !_loadFailed &&
        _draft.canSave;

    return Scaffold(
      appBar: AppBar(title: const Text('Создай своего Финни')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FinnyPreview(
                    colorId: _draft.colorId,
                    patternId: _draft.patternId,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  if (profileId == null)
                    const _FriendlyNotice(
                      'Сначала открой свой профиль, чтобы сохранить Финни.',
                    )
                  else if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_loadFailed) ...[
                    const _FriendlyNotice(
                      'Не получилось загрузить Финни. Попробуй ещё раз.',
                    ),
                    TextButton(
                      onPressed: () => _loadForProfile(profileId),
                      child: const Text('Повторить'),
                    ),
                  ],
                  if (_saveFailed)
                    const _FriendlyNotice(
                      'Не получилось сохранить Финни. Попробуй ещё раз.',
                    ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'Как его зовут?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  TextField(
                    controller: _nameController,
                    enabled: !_loading && !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Имя Финни',
                      border: const OutlineInputBorder(),
                      errorText: _nameTouched ? _draft.nameError : null,
                    ),
                    onChanged: (value) => setState(() {
                      _draft = _draft.copyWith(name: value);
                      _nameTouched = true;
                      _saveFailed = false;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    'Выбери цвет',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _choices(
                    values: PetCreationDraft.colorIds,
                    selected: _draft.colorId,
                    labels: const {
                      'blue': 'Синий',
                      'purple': 'Фиолетовый',
                      'mint': 'Мятный',
                    },
                    onSelect: (value) => setState(() {
                      _draft = _draft.copyWith(colorId: value);
                      _saveFailed = false;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    'Выбери узор',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  _choices(
                    values: PetCreationDraft.patternIds,
                    selected: _draft.patternId,
                    labels: const {
                      'plain': 'Без узора',
                      'spots': 'Пятнышки',
                      'stripes': 'Полоски',
                    },
                    onSelect: (value) => setState(() {
                      _draft = _draft.copyWith(patternId: value);
                      _saveFailed = false;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.extraLarge),
                  FilledButton(
                    onPressed: canSave ? _save : null,
                    child: Text(_saving ? 'Сохраняем…' : 'Создать Финни'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choices({
    required List<String> values,
    required String selected,
    required Map<String, String> labels,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: [
        for (final value in values)
          ChoiceChip(
            key: Key('pet-choice-$value'),
            avatar: Icon(
              Icons.check,
              size: 18,
              color: selected == value
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Colors.transparent,
            ),
            avatarBoxConstraints: const BoxConstraints.tightFor(
              width: 18,
              height: 18,
            ),
            label: Text(labels[value]!),
            selected: selected == value,
            showCheckmark: false,
            onSelected: _saving || _loading ? null : (_) => onSelect(value),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            labelPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
          ),
      ],
    );
  }
}

class _FriendlyNotice extends StatelessWidget {
  const _FriendlyNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Text(message),
    ),
  );
}
