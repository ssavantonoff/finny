import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/content_repository.dart';

class CampaignLifecycleService {
  CampaignLifecycleService(this._repository, this._content);

  final CampaignLifecycleRepository _repository;
  final ContentRepository _content;

  Future<CampaignLifecycleSnapshot> load(int profileId) async {
    if (!await _repository.hasFivePeriods(profileId)) {
      return const CampaignLifecycleSnapshot(mode: CampaignMode.campaign);
    }
    return _repository.load(profileId, await _content.loadPeriods());
  }

  Future<CampaignLifecycleSnapshot> finishStory(int profileId) async =>
      _repository.finishStory(profileId, await _content.loadPeriods());

  Future<CampaignLifecycleSnapshot> startFreePlay(int profileId) async =>
      _repository.startFreePlay(profileId, await _content.loadPeriods());
}
