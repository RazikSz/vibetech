import 'package:flutter/material.dart';

/// ============================================================================
/// ENUM & MODEL TIER KEMITRAAN RESELLER (RESELLER TIER)
/// ============================================================================
enum ResellerTierLevel {
  standard,
  silver,
  gold,
  platinum,
}

class ResellerTierInfo {
  final ResellerTierLevel level;
  final String title;
  final String badgeText;
  final double minSpending;
  final int minReferrals;
  final double commissionRate; // e.g. 0.05 = 5%
  final double discountRate;   // e.g. 0.05 = 5%
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;
  final String description;

  const ResellerTierInfo({
    required this.level,
    required this.title,
    required this.badgeText,
    required this.minSpending,
    required this.minReferrals,
    required this.commissionRate,
    required this.discountRate,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
    required this.description,
  });

  String get commissionPercentText => '${(commissionRate * 100).toStringAsFixed(commissionRate * 100 % 1 == 0 ? 0 : 1)}%';
  String get discountPercentText => '${(discountRate * 100).toStringAsFixed(discountRate * 100 % 1 == 0 ? 0 : 1)}%';
}

class ResellerTierHelper {
  static const ResellerTierInfo standardTier = ResellerTierInfo(
    level: ResellerTierLevel.standard,
    title: 'Standard Member',
    badgeText: 'STANDARD',
    minSpending: 0,
    minReferrals: 0,
    commissionRate: 0.05, // 5%
    discountRate: 0.0,    // 0%
    primaryColor: Color(0xFF6B7280),
    secondaryColor: Color(0xFF4B5563),
    icon: Icons.person_outline_rounded,
    description: 'Tier awal untuk semua member VibeTech. Nikmati komisi referral 5% saldo.',
  );

  static const ResellerTierInfo silverTier = ResellerTierInfo(
    level: ResellerTierLevel.silver,
    title: 'Silver Reseller',
    badgeText: 'SILVER 🥈',
    minSpending: 500000,
    minReferrals: 3,
    commissionRate: 0.075, // 7.5%
    discountRate: 0.05,    // 5%
    primaryColor: Color(0xFF94A3B8),
    secondaryColor: Color(0xFF64748B),
    icon: Icons.shield_outlined,
    description: 'Komisi referral naik jadi 7.5% + diskon belanja 5% otomatis untuk VPS & Panel.',
  );

  static const ResellerTierInfo goldTier = ResellerTierInfo(
    level: ResellerTierLevel.gold,
    title: 'Gold Partner',
    badgeText: 'GOLD 🥇',
    minSpending: 2000000,
    minReferrals: 10,
    commissionRate: 0.10, // 10%
    discountRate: 0.10,   // 10%
    primaryColor: Color(0xFFF59E0B),
    secondaryColor: Color(0xFFD97706),
    icon: Icons.workspace_premium_rounded,
    description: 'Komisi referral 10% + diskon 10% di seluruh produk & prioritas aktivasi instan.',
  );

  static const ResellerTierInfo platinumTier = ResellerTierInfo(
    level: ResellerTierLevel.platinum,
    title: 'Platinum VIP',
    badgeText: 'PLATINUM 💎',
    minSpending: 5000000,
    minReferrals: 25,
    commissionRate: 0.15, // 15%
    discountRate: 0.15,   // 15%
    primaryColor: Color(0xFF06B6D4),
    secondaryColor: Color(0xFF0891B2),
    icon: Icons.military_tech_rounded,
    description: 'Tingkatan tertinggi! Komisi referral 15%, diskon belanja 15%, dan dedicated VIP Support.',
  );

  static List<ResellerTierInfo> get allTiers => [
    standardTier,
    silverTier,
    goldTier,
    platinumTier,
  ];

  /// Menentukan Tier berdasarkan total belanja dan jumlah referral
  static ResellerTierInfo getTier({required double totalSpending, required int referralCount}) {
    if (totalSpending >= platinumTier.minSpending || referralCount >= platinumTier.minReferrals) {
      return platinumTier;
    }
    if (totalSpending >= goldTier.minSpending || referralCount >= goldTier.minReferrals) {
      return goldTier;
    }
    if (totalSpending >= silverTier.minSpending || referralCount >= silverTier.minReferrals) {
      return silverTier;
    }
    return standardTier;
  }

  /// Menghitung komisi referral berdasarkan total transaksi
  static double calculateCommission(double amount, ResellerTierInfo tier) {
    return amount * tier.commissionRate;
  }

  /// Menghitung diskon pembelian berdasarkan tier member
  static double calculateDiscount(double amount, ResellerTierInfo tier) {
    return amount * tier.discountRate;
  }

  /// Mendapatkan tier selanjutnya dan progres belanja/referral
  static (ResellerTierInfo? nextTier, double progress, double remainingAmount) getNextTierProgress({
    required double totalSpending,
    required int referralCount,
  }) {
    final currentTier = getTier(totalSpending: totalSpending, referralCount: referralCount);
    if (currentTier.level == ResellerTierLevel.platinum) {
      return (null, 1.0, 0.0);
    }

    final ResellerTierInfo targetTier;
    final double prevThreshold;
    if (currentTier.level == ResellerTierLevel.standard) {
      targetTier = silverTier;
      prevThreshold = 0;
    } else if (currentTier.level == ResellerTierLevel.silver) {
      targetTier = goldTier;
      prevThreshold = silverTier.minSpending;
    } else {
      targetTier = platinumTier;
      prevThreshold = goldTier.minSpending;
    }

    final diff = targetTier.minSpending - prevThreshold;
    final userDiff = (totalSpending - prevThreshold).clamp(0, diff);
    final progress = diff > 0 ? (userDiff / diff).clamp(0.0, 1.0) : 1.0;
    final remaining = (targetTier.minSpending - totalSpending).clamp(0.0, targetTier.minSpending);

    return (targetTier, progress, remaining);
  }
}

/// Model riwayat komisi referral yang diterima pengguna
class ReferralHistoryItem {
  final int? id;
  final String referrerEmail;
  final String buyerEmail;
  final double orderAmount;
  final double commissionAmount;
  final String tier;
  final String invoiceNo;
  final String createdAt;

  ReferralHistoryItem({
    this.id,
    required this.referrerEmail,
    required this.buyerEmail,
    required this.orderAmount,
    required this.commissionAmount,
    required this.tier,
    required this.invoiceNo,
    required this.createdAt,
  });

  factory ReferralHistoryItem.fromMap(Map<String, dynamic> map) {
    return ReferralHistoryItem(
      id: map['id'] as int?,
      referrerEmail: map['referrerEmail']?.toString() ?? '',
      buyerEmail: map['buyerEmail']?.toString() ?? '',
      orderAmount: (map['orderAmount'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0.0,
      tier: map['tier']?.toString() ?? 'Standard',
      invoiceNo: map['invoiceNo']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'referrerEmail': referrerEmail,
      'buyerEmail': buyerEmail,
      'orderAmount': orderAmount,
      'commissionAmount': commissionAmount,
      'tier': tier,
      'invoiceNo': invoiceNo,
      'createdAt': createdAt,
    };
  }
}
