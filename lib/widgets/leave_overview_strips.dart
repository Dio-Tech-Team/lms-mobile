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

    final totalDays = vlTotal + slTotal;
    final usedDays = vlUsed + slUsed;
    final remaining = totalDays - usedDays;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "OVERVIEW",
                      style: GoogleFonts.nunito(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4EEAAA).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'VL + SL',
                        style: GoogleFonts.nunito(
                          color: const Color(0xFF4EEAAA),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(
                    '${year ?? DateTime.now().year}',
                    style: GoogleFonts.nunito(
                      color: Colors.white38,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _stat(
                icon: Icons.event_available_rounded,
                value: totalDays % 1 == 0
                    ? '${totalDays.toInt()}'
                    : '$totalDays',
                label: 'Total',
              ),
              _divider(),
              _stat(
                icon: Icons.flight_takeoff_rounded,
                value: usedDays % 1 == 0 ? '${usedDays.toInt()}' : '$usedDays',
                label: 'Used',
              ),
              _divider(),
              _stat(
                icon: Icons.savings_rounded,
                value: remaining % 1 == 0
                    ? '${remaining.toInt()}'
                    : '$remaining',
                label: 'Remaining',
                highlight: true,
              ),
              _divider(),
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

  Widget _divider() {
    return Container(
      height: 34,
      width: 1,
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _stat({
    required IconData icon,
    required String value,
    required String label,
    bool highlight = false,
  }) {
    final color = highlight ? const Color(0xFF4EEAAA) : Colors.white;
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 17,
            color: highlight ? const Color(0xFF4EEAAA) : Colors.white60,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.fraunces(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}