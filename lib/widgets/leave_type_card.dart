import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

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

  /// Height reserved for the title. Two lines at 11px with height 1.2 is
  /// ~26.4px; the card must reserve that whether or not this particular
  /// leave type's name actually wraps, so every card in the horizontal
  /// list aligns its number at the same baseline.
  static const double _titleBlockHeight = 28;

  String _fmt(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final bigValue = isDynamic ? remaining : total;
    final subtitleValue = isDynamic ? total : remaining;

    // A leave type with total <= 0 simply hasn't been initialized/granted
    // yet — that is NOT the same thing as a genuinely low remaining
    // balance, so it must not get the same red "warning" treatment.
    final notYetAvailable = total <= 0;
    final isLow = !notYetAvailable && remaining <= 2;
    final accent = isLow ? const Color(0xFFE0475A) : accentColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          SizedBox(
            height: _titleBlockHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    leaveType,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.1,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notYetAvailable
                        ? Icons.hourglass_empty_rounded
                        : isLow
                        ? Icons.warning_amber_rounded
                        : Icons.calendar_today_rounded,
                    size: 13,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (notYetAvailable) ...[
            const Spacer(),
            Text(
              'Not yet\navailable',
              style: AppText.body(
                size: 12,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
            const Spacer(),
          ] else ...[
            Text(
              _fmt(bigValue),
              style: AppText.display(
                size: 28,
                weight: FontWeight.w700,
                color: AppColors.navyDark,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'of ${_fmt(subtitleValue)} days left',
              style: AppText.body(
                size: 11,
                weight: FontWeight.w500,
                color: AppColors.muted,
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
        ],
      ),
    );
  }
}
