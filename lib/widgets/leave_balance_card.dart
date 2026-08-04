import 'package:flutter/material.dart';

class LeaveBalanceCard extends StatelessWidget {
  final double totalDays;
  final double usedDays;
  final double remaining;
  final double overallProgress;
  final dynamic year;
  final String? employeeName;

  const LeaveBalanceCard({
    super.key,
    required this.totalDays,
    required this.usedDays,
    required this.remaining,
    required this.overallProgress,
    this.year,
    this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
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
            'LEAVE BALANCE — ${year ?? DateTime.now().year}',
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
                      const Text('Remaining',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        remaining % 1 == 0
                            ? '${remaining.toInt()}'
                            : '$remaining',
                        style: const TextStyle(
                          color: Color(0xFF4EEAAA),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${usedDays % 1 == 0 ? usedDays.toInt() : usedDays} used this year',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used: ${usedDays % 1 == 0 ? usedDays.toInt() : usedDays} days',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              Text(
                '${(overallProgress * 100).toStringAsFixed(0)}% consumed',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4EEAAA)),
            ),
          ),
        ],
      ),
    );
  }
}