import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/models/referral_tier_model.dart';

void main() {
  group('Reseller Tier & Referral Calculation Tests', () {
    test('Standard Tier default', () {
      final tier = ResellerTierHelper.getTier(totalSpending: 0, referralCount: 0);
      expect(tier.level, equals(ResellerTierLevel.standard));
      expect(tier.commissionRate, equals(0.05));
      expect(tier.discountRate, equals(0.0));

      final comm = ResellerTierHelper.calculateCommission(100000, tier);
      expect(comm, equals(5000.0));
    });

    test('Silver Tier upgrade via spending or referral count', () {
      // By spending
      final tierSpending = ResellerTierHelper.getTier(totalSpending: 550000, referralCount: 1);
      expect(tierSpending.level, equals(ResellerTierLevel.silver));
      expect(tierSpending.commissionRate, equals(0.075));
      expect(tierSpending.discountRate, equals(0.05));

      // By referrals
      final tierRef = ResellerTierHelper.getTier(totalSpending: 100000, referralCount: 3);
      expect(tierRef.level, equals(ResellerTierLevel.silver));
    });

    test('Gold & Platinum Tier calculations', () {
      final goldTier = ResellerTierHelper.getTier(totalSpending: 2500000, referralCount: 5);
      expect(goldTier.level, equals(ResellerTierLevel.gold));
      expect(goldTier.commissionRate, equals(0.10));
      expect(goldTier.discountRate, equals(0.10));

      final platTier = ResellerTierHelper.getTier(totalSpending: 5000000, referralCount: 25);
      expect(platTier.level, equals(ResellerTierLevel.platinum));
      expect(platTier.commissionRate, equals(0.15));
      expect(platTier.discountRate, equals(0.15));

      final comm = ResellerTierHelper.calculateCommission(200000, platTier);
      expect(comm, equals(30000.0)); // 15% of 200,000 = 30,000
    });
  });
}
