import 'package:flutter/material.dart';

class LeaveTypeCard extends StatelessWidget {
  final String leaveType;
  final double remaining;
  final double total;
  final double used;
  final Color accentColor;

  const LeaveTypeCard({
    super.key,
    required this.leaveType,
    required this.remaining,
    required this.total,
    required this.used,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final isLow = remaining <= 2;
    final accent = isLow ? Colors.red : accentColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    leaveType,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.calendar_today_rounded, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            remaining % 1 == 0 ? '${remaining.toInt()}' : '$remaining',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          Text(
            'of ${total % 1 == 0 ? total.toInt() : total} days left',
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A97A8)),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}