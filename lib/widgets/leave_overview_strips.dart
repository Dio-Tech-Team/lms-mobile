import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaveOverviewStrip extends StatelessWidget {
  final List<dynamic> credits;
  final int pendingCount;
  final dynamic year;
  final Map<String, double> approvedUsedByType;

  const LeaveOverviewStrip({
    super.key,
    required this.credits,
    required this.pendingCount,
    this.approvedUsedByType = const {},
    this.year,
  });

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  Map<String, dynamic>? _findLeaveType(String name) {
    for (final c in credits) {
      final typeName = (c["leave_type"] ?? c["name"] ?? "").toString();
      if (typeName == name) return c as Map<String, dynamic>;
    }
    return null;
  }

  double _field(Map<String, dynamic>? entry, String key) =>
      entry != null ? _toDouble(entry[key]) : 0.0;

  @override
  Widget build(BuildContext context) {
    final vlEntry = _findLeaveType('Vacation Leave');
    final slEntry = _findLeaveType('Sick Leave');

    final vlUsed = approvedUsedByType['Vacation Leave'] ?? 0;
    final slUsed = approvedUsedByType['Sick Leave'] ?? 0;
    final vlRemaining = _field(vlEntry, "remaining_balance");
    final slRemaining = _field(slEntry, "remaining_balance");
    final vlTotal = _field(vlEntry, "total_credits") > 0
        ? _field(vlEntry, "total_credits")
        : vlRemaining + vlUsed;
    final slTotal = _field(slEntry, "total_credits") > 0
        ? _field(slEntry, "total_credits")
        : slRemaining + slUsed;
    final usedDays = vlUsed + slUsed;
    final remaining = vlRemaining + slRemaining;

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
                Text(
                  "OVERVIEW",
                  style: GoogleFonts.nunito(
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
                    style: GoogleFonts.nunito(
                      color: Colors.white38,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _stat(
                value: vlRemaining % 1 == 0
                    ? '${vlRemaining.toInt()}'
                    : '$vlRemaining',
                label: 'VL',
              ),
              _stat(
                value: slRemaining % 1 == 0
                    ? '${slRemaining.toInt()}'
                    : '$slRemaining',
                label: 'SL',
              ),
              _stat(
                icon: Icons.flight_takeoff_rounded,
                value: usedDays % 1 == 0 ? '${usedDays.toInt()}' : '$usedDays',
                label: 'Used',
              ),
              _stat(
                icon: Icons.savings_rounded,
                value: remaining % 1 == 0
                    ? '${remaining.toInt()}'
                    : '$remaining',
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
    IconData? icon,
    required String value,
    required String label,
    bool highlight = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: highlight ? const Color(0xFF4EEAAA) : Colors.white70,
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 24),
          Text(
            value,
            style: GoogleFonts.fraunces(
              color: highlight ? const Color(0xFF4EEAAA) : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white54,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}