import 'package:flutter/material.dart';

class LeaveOverviewStrip extends StatelessWidget {
  final double totalDays;
  final double usedDays;
  final double remaining;
  final int pendingCount;
  final dynamic year;

  const LeaveOverviewStrip({
    super.key,
    required this.totalDays,
    required this.usedDays,
    required this.remaining,
    required this.pendingCount,
    this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "OVERVIEW",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${year ?? DateTime.now().year}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _stat(
                icon: Icons.event_available_rounded,
                value: totalDays % 1 == 0 ? '${totalDays.toInt()}' : '$totalDays',
                label: 'Total',
              ),
              _stat(
                icon: Icons.flight_takeoff_rounded,
                value: usedDays % 1 == 0 ? '${usedDays.toInt()}' : '$usedDays',
                label: 'Used',
              ),
              _stat(
                icon: Icons.savings_rounded,
                value: remaining % 1 == 0 ? '${remaining.toInt()}' : '$remaining',
                label: 'Remaining',
                highlight: true,
              ),
              _stat(
                icon: Icons.pending_actions_rounded,
                value: '$pendingCount',
                label: 'Pending',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String value,
    required String label,
    bool highlight = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 18,
              color: highlight ? const Color(0xFF4EEAAA) : Colors.white70),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF4EEAAA) : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}