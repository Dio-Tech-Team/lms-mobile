import 'package:flutter/material.dart';

class LeaveBalanceCard extends StatelessWidget {
  final double totalDays;
  final double usedDays;
  final double remaining;
  final double overallProgress;
  final dynamic year;
  final String? employeeName;

  /// Vacation Leave remaining balance only — this is what's eligible
  /// for monetization (VL only, not combined with Sick Leave).
  final double vlMonetizable;

  /// Called when the user taps "Apply for Monetization".
  /// If null, tapping shows a "coming soon" message instead.
  final VoidCallback? onApplyMonetization;

  static const double monetizationMinimumDays = 10;

  const LeaveBalanceCard({
    super.key,
    required this.totalDays,
    required this.usedDays,
    required this.remaining,
    required this.overallProgress,
    required this.vlMonetizable,
    this.onApplyMonetization,
    this.year,
    this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    final isEligible = vlMonetizable >= monetizationMinimumDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5491)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Total Balance for the Year ${year ?? DateTime.now().year}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Credits',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        totalDays % 1 == 0
                            ? '${totalDays.toInt()}'
                            : '$totalDays',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('days allocated',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Can Monetize',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        vlMonetizable % 1 == 0
                            ? '${vlMonetizable.toInt()}'
                            : '$vlMonetizable',
                        style: const TextStyle(
                          color: Color(0xFF4EEAAA),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isEligible
                            ? 'Eligible · min. ${monetizationMinimumDays.toInt()} VL days'
                            : 'Requires min. ${monetizationMinimumDays.toInt()} VL days',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApplyMonetization ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Monetization application is coming soon.',
                        ),
                      ),
                    );
                  },
              icon: const Icon(Icons.savings_outlined, size: 18),
              label: const Text('Apply for Monetization'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4EEAAA),
                foregroundColor: const Color(0xFF13224A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}