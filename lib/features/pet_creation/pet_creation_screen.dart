import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/onboarding/welcome_visuals.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/features/pet_creation/pet_creation_draft.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
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
              developmentStage: 1,
              growthPoints: 0,
              satiety: PetStateRules.dayOneInitialSatiety,
              care: PetStateRules.dayOneInitialCare,
              mood: PetStateRules.dayOneInitialMood,
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
    ref.listen<int?>(
      activeProfileIdProvider,
      (_, next) => _loadForProfile(next),
    );
    final canSave =
        profileId != null &&
        profileId == _loadedProfileId &&
        !_loading &&
        !_saving &&
        !_loadFailed &&
        _draft.canSave;
    return Scaffold(
      body: WelcomeBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FinnyBrand(),
                    const SizedBox(height: 16),
                    const Text(
                      'Создай своего Финни',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Выбери, каким будет твой новый друг.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FinnyPreview(
                      colorId: _draft.colorId,
                      patternId: _draft.patternId,
                      developmentStage: _existingPet?.developmentStage ?? 1,
                      name: _draft.trimmedName.isEmpty
                          ? 'Финни'
                          : _draft.trimmedName,
                      height: 210,
                    ),
                    if (profileId == null)
                      const _FriendlyNotice(
                        'Сначала открой свой профиль, чтобы сохранить Финни.',
                      )
                    else if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                      )
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x176C5CE7),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Как назовём Финни?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Имя Финни',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            enabled: !_loading && !_saving,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            decoration: welcomeInputDecoration(
                              hint: 'Например, Пикси',
                              error: _nameTouched ? _draft.nameError : null,
                            ),
                            onChanged: (value) => setState(() {
                              _draft = _draft.copyWith(name: value);
                              _nameTouched = true;
                              _saveFailed = false;
                            }),
                            onSubmitted: (_) {
                              if (canSave) _save();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Выбери цвет',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _choices(colors: true),
                    const SizedBox(height: 20),
                    const Text(
                      'Выбери узор',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _choices(colors: false),
                    const SizedBox(height: 26),
                    WelcomeButton(
                      label: _saving ? 'Сохраняем…' : 'Создать Финни',
                      onPressed: canSave ? _save : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choices({required bool colors}) {
    final values = colors
        ? PetCreationDraft.colorIds
        : PetCreationDraft.patternIds;
    final selected = colors ? _draft.colorId : _draft.patternId;
    final labels = colors
        ? const {'purple': 'Фиолетовый', 'blue': 'Синий', 'mint': 'Мятный'}
        : const {
            'plain': 'Без узора',
            'spots': 'Пятнышки',
            'stripes': 'Полоски',
          };
    final swatchColor = switch (_draft.colorId) {
      'blue' => const Color(0xFF4DA3FF),
      'mint' => const Color(0xFF4ADBC8),
      _ => AppColors.primary,
    };
    return Row(
      children: [
        for (final value in values) ...[
          if (value != values.first) const SizedBox(width: 8),
          Expanded(
            child: PetAppearanceOption(
              key: Key('pet-choice-$value'),
              label: labels[value]!,
              selected: selected == value,
              swatchColor: colors
                  ? switch (value) {
                      'blue' => const Color(0xFF4DA3FF),
                      'mint' => const Color(0xFF4ADBC8),
                      _ => AppColors.primary,
                    }
                  : swatchColor,
              pattern: colors ? 'plain' : value,
              onTap: _saving || _loading
                  ? null
                  : () => setState(() {
                      _draft = colors
                          ? _draft.copyWith(colorId: value)
                          : _draft.copyWith(patternId: value);
                      _saveFailed = false;
                    }),
            ),
          ),
        ],
      ],
    );
  }
}

class PetAppearanceOption extends StatelessWidget {
  const PetAppearanceOption({
    required this.label,
    required this.selected,
    required this.swatchColor,
    required this.pattern,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final Color swatchColor;
  final String pattern;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x126C5CE7),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(alignment: const Alignment(0, -0.35), child: _swatch()),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (selected)
              const Align(
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _swatch() => Container(
    width: 55,
    height: 55,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: swatchColor,
      gradient: RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 1,
        colors: [Color.lerp(swatchColor, Colors.white, 0.42)!, swatchColor],
      ),
    ),
    child: pattern == 'plain'
        ? null
        : Center(
            child: pattern == 'spots'
                ? const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xAAFFFFFF),
                    size: 28,
                  )
                : const Icon(
                    Icons.menu_rounded,
                    color: Color(0xAAFFFFFF),
                    size: 29,
                  ),
          ),
  );
}

class _FriendlyNotice extends StatelessWidget {
  const _FriendlyNotice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
  );
}
