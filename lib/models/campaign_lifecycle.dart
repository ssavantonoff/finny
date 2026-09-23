enum CampaignMode { campaign, finalePending, campaignFinished, freePlay }

class CampaignLifecycleSnapshot {
  const CampaignLifecycleSnapshot({
    required this.mode,
    this.finaleAcknowledgedAt,
    this.freePlayStartedAt,
  });

  final CampaignMode mode;
  final DateTime? finaleAcknowledgedAt;
  final DateTime? freePlayStartedAt;

  bool get campaignCompleted => mode != CampaignMode.campaign;
}
