import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/services/campaign_lifecycle_service.dart';

import 'test_content_repository.dart';
import 'test_database.dart';

class CampaignOnlyLifecycleService extends CampaignLifecycleService {
  CampaignOnlyLifecycleService()
    : super(
        CampaignLifecycleRepository(createTestDatabase()),
        TestContentRepository(const []),
      );

  @override
  Future<CampaignLifecycleSnapshot> load(int profileId) async =>
      const CampaignLifecycleSnapshot(mode: CampaignMode.campaign);
}
