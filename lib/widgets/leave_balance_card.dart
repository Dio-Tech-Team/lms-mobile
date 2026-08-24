import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screentabs/leave_monetization.dart';

class LeaveBalanceCard extends StatelessWidget {
  final double totalDays;
  final double usedDays;
  final double remaining;
  final double overallProgress;
  final dynamic year;
  final String? employeeName;
  final double vlMonetizable;
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
            style: GoogleFonts.nunito(
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
                      Text(
                        'Total Credits',
                        style: GoogleFonts.nunito(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalDays % 1 == 0
                            ? '${totalDays.toInt()}'
                            : '$totalDays',
                        style: GoogleFonts.fraunces(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'days allocated',
                        style: GoogleFonts.nunito(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
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
                      Text(
                        'Can Monetize',
                        style: GoogleFonts.nunito(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vlMonetizable % 1 == 0
                            ? '${vlMonetizable.toInt()}'
                            : '$vlMonetizable',
                        style: GoogleFonts.fraunces(
                          color: const Color(0xFF4EEAAA),
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isEligible
                            ? 'Eligible · min. ${monetizationMinimumDays.toInt()} VL days'
                            : 'Requires min. ${monetizationMinimumDays.toInt()} VL days',
                        style: GoogleFonts.nunito(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ApplyForLeaveMonetization(),
                      ),
                    );
                  },
              icon: const Icon(Icons.savings_outlined, size: 18),
              label: Text(
                'Apply for Monetization',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4EEAAA),
                foregroundColor: const Color(0xFF13224A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}