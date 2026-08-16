import 'package:flutter/material.dart';

class LeaveTypeCard extends StatelessWidget {
  final String leaveType;
  final double remaining;
  final double total;
  final double used;
  final Color accentColor;

  /// True for accruing types (Vacation Leave, Sick Leave) where both the
  /// cap and the remaining balance genuinely change over time.
  /// False for fixed-allocation types (e.g. Wellness Leave), where the
  /// cap is a static number and only the remaining balance moves.
  final bool isDynamic;

  const LeaveTypeCard({
    super.key,
    required this.leaveType,
    required this.remaining,
    required this.total,
    required this.used,
    required this.accentColor,
    this.isDynamic = true,
  });

  @override
  Widget build(BuildContext context) {
    // Progress and the low-balance warning always reflect the real
    // numbers, regardless of which one is shown as the "big" figure.
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final isLow = remaining <= 2;
    final accent = isLow ? Colors.red : accentColor;

    // Dynamic types: big number = remaining, subtitle = "of {total} days left".
    // Static types: big number = total (fixed cap), subtitle = "of {remaining} days left".
    final bigValue = isDynamic ? remaining : total;
    final subtitleValue = isDynamic ? total : remaining;

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
                    maxLines: 1,
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
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
            bigValue % 1 == 0 ? '${bigValue.toInt()}' : '$bigValue',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          Text(
            'of ${subtitleValue % 1 == 0 ? subtitleValue.toInt() : subtitleValue} days left',
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