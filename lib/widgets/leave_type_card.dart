import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaveTypeCard extends StatelessWidget {
  final String leaveType;
  final double remaining;
  final double total;
  final double used;
  final Color accentColor;
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
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final isLow = remaining <= 2;
    final accent = isLow ? const Color(0xFFE0475A) : accentColor;
    final bigValue = isDynamic ? remaining : total;
    final subtitleValue = isDynamic ? total : remaining;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    leaveType,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.nunito(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLow
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_rounded,
                  size: 13,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bigValue % 1 == 0 ? '${bigValue.toInt()}' : '$bigValue',
            style: GoogleFonts.fraunces(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF13224A),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'of ${subtitleValue % 1 == 0 ? subtitleValue.toInt() : subtitleValue} days left',
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: const Color(0xFF8A97A8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: accent.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}