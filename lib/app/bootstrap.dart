import 'package:finny/app/providers.dart';
import 'package:finny/features/onboarding/profile_name.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BootstrapPhase {
  loading,
  onboardingNew,
  onboardingExisting,
  resolvedWithoutPet,
  resolvedWithPet,
  error,
  profileConflict,
}

class BootstrapState {
  const BootstrapState(
    this.phase, {
    this.profile,
    this.submitting = false,
    this.saveFailed = false,
    this.destination,
  });

  final BootstrapPhase phase;
  final Profile? profile;
  final bool submitting;
  final bool saveFailed;
  final String? destination;
}

final bootstrapProvider = NotifierProvider<BootstrapController, BootstrapState>(
  BootstrapController.new,
);

class BootstrapController extends Notifier<BootstrapState> {
  Future<void>? _pending;

  @override
  BootstrapState build() => const BootstrapState(BootstrapPhase.loading);

  Future<void> initialize() => _run(() async {
    state = const BootstrapState(BootstrapPhase.loading);
    try {
      final profiles = await ref.read(profileRepositoryProvider).findAll();
      final normal = profiles
          .where((profile) => profile.profileType == ProfileType.normal)
          .toList(growable: false);
      if (normal.length > 1) {
        ref.read(activeProfileIdProvider.notifier).clear();
        state = const BootstrapState(BootstrapPhase.profileConflict);
      } else if (normal.isEmpty) {
        state = const BootstrapState(BootstrapPhase.onboardingNew);
      } else if (!normal.single.onboardingCompleted) {
        state = BootstrapState(
          BootstrapPhase.onboardingExisting,
          profile: normal.single,
        );
      } else {
        await _resolve(normal.single);
      }
    } catch (_) {
      state = const BootstrapState(BootstrapPhase.error);
    }
  });

  Future<void> submitName(String input) {
    if (_pending != null || !ProfileName(input).isValid) {
      return Future.value();
    }
    final current = state;
    if (current.phase != BootstrapPhase.onboardingNew &&
        current.phase != BootstrapPhase.onboardingExisting) {
      return Future.value();
    }
    return _run(() async {
      state = BootstrapState(
        current.phase,
        profile: current.profile,
        submitting: true,
      );
      Profile profile;
      try {
        final repository = ref.read(profileRepositoryProvider);
        if (current.phase == BootstrapPhase.onboardingNew) {
          profile = await repository.create(
            Profile(
              gameName: ProfileName(input).trimmed,
              profileType: ProfileType.normal,
              onboardingCompleted: true,
              createdAt: DateTime.now().toUtc(),
            ),
          );
        } else {
          profile = current.profile!.copyWith(
            gameName: ProfileName(input).trimmed,
            onboardingCompleted: true,
          );
          await repository.update(profile);
        }
      } catch (_) {
        state = BootstrapState(
          current.phase,
          profile: current.profile,
          saveFailed: true,
        );
        return;
      }
      try {
        await _resolve(
          profile,
          newProfile: current.phase == BootstrapPhase.onboardingNew,
        );
      } catch (_) {
        state = const BootstrapState(BootstrapPhase.error);
      }
    });
  }

  Future<void> retryName(String input) async {
    await initialize();
    if (state.phase == BootstrapPhase.onboardingNew ||
        state.phase == BootstrapPhase.onboardingExisting) {
      await submitName(input);
    }
  }

  Future<void> _resolve(Profile profile, {bool newProfile = false}) async {
    final id = profile.id;
    if (id == null || id <= 0) throw StateError('Profile has no persisted ID.');
    final game = ref.read(gameRepositoryProvider);
    await game.ensureInitialState(id);
    ref.read(activeProfileIdProvider.notifier).setActiveProfileId(id);
    if (newProfile) {
      state = const BootstrapState(BootstrapPhase.resolvedWithoutPet);
      return;
    }
    final pet = await game.getPet(id);
    final mode = pet == null
        ? CampaignMode.campaign
        : (await ref.read(campaignLifecycleServiceProvider).load(id)).mode;
    state = BootstrapState(
      pet == null
          ? BootstrapPhase.resolvedWithoutPet
          : BootstrapPhase.resolvedWithPet,
      destination: switch (mode) {
        CampaignMode.finalePending => '/finale',
        CampaignMode.campaignFinished => '/campaign-complete',
        _ => '/home',
      },
    );
  }

  Future<void> _run(Future<void> Function() action) {
    final pending = _pending;
    if (pending != null) return pending;
    final operation = action();
    _pending = operation;
    return operation.whenComplete(() => _pending = null);
  }
}
