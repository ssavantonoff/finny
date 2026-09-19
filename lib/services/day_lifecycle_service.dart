import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class DayLifecycleService {
  DayLifecycleService(this._port, this._contentRepository);

  final DayLifecyclePort _port;
  final ContentRepository _contentRepository;

  Future<BedtimeDecision> evaluateBedtime({
    required int profileId,
    required int periodId,
  }) async => _port.evaluateBedtime(
    profileId: profileId,
    periodId: periodId,
    canonicalItems: await _contentRepository.loadShopItems(),
  );

  Future<DayCompletionResult> sleep({
    required int profileId,
    required int periodId,
    required bool allowFallback,
  }) async => _port.sleep(
    profileId: profileId,
    periodId: periodId,
    allowFallback: allowFallback,
    canonicalItems: await _contentRepository.loadShopItems(),
  );
}
