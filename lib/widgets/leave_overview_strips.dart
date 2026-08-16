import 'package:flutter/material.dart';

class LeaveOverviewStrip extends StatelessWidget {
  final List<dynamic> credits;
  final int pendingCount;
  final dynamic year;

  /// Leave type name -> total approved days_applied, from actual approved
  /// applications. Used to reconstruct each type's true total, since the
  /// API's used_credits/total_credits fields aren't reliable, and
  /// remaining_balance may or may not already be decremented depending on
  /// the leave type.
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
    // Total/Used/Remaining reflect combined Vacation Leave + Sick Leave
    // only (the leave people actually track day-to-day) — not a sum of
    // all leave types, which mixes unrelated fixed allocations together
    // and isn't a meaningful single number.
    final vlEntry = _findLeaveType('Vacation Leave');
    final slEntry = _findLeaveType('Sick Leave');

    final vlUsed = approvedUsedByType['Vacation Leave'] ?? 0;
    final slUsed = approvedUsedByType['Sick Leave'] ?? 0;
    final vlRemaining = _field(vlEntry, "remaining_balance");
    final slRemaining = _field(slEntry, "remaining_balance");

    // Reconstruct each type's true total as remaining + used, rather than
    // trusting the API's total_credits (unreliable) or assuming
    // remaining_balance is untouched by approvals (it isn't, always —
    // some leave types get decremented on approval, some don't). This
    // formula gives the correct total either way.
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
                Row(
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VL + SL',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
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