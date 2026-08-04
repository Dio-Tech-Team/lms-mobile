import 'package:flutter/foundation.dart';

/// A leave type available for selection when applying for leave,
/// normalized from whatever shape the backend sends it in.
class LeaveTypeOption {
  final int id;
  final String name;
  final String? code;
  final double remainingBalance;

  const LeaveTypeOption({
    required this.id,
    required this.name,
    this.code,
    required this.remainingBalance,
  });

  @override
  bool operator ==(Object other) =>
      other is LeaveTypeOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Parses a raw list of leave-type maps (e.g. from an API response)
  /// into a list of [LeaveTypeOption]s, tolerating several possible
  /// key names for id/name/balance/code.
  static List<LeaveTypeOption> listFromJson(List<dynamic>? raw) {
    final types = raw ?? [];
    debugPrint("DEBUG LeaveTypeOption received types: $types");

    final options = <LeaveTypeOption>[];

    for (int i = 0; i < types.length; i++) {
      final c = types[i];
      if (c is! Map) continue;

      final rawId = c["leave_configuration_id"] ?? c["id"] ?? c["leave_type_id"];
      int intId;
      if (rawId != null) {
        intId = rawId is int ? rawId : (int.tryParse(rawId.toString()) ?? i + 1);
      } else {
        intId = c["code"]?.hashCode ?? (i + 1);
      }

      final name = (c["name"] ?? c["leave_type"] ?? c["leave_type_name"] ?? "Leave").toString();

      final rawBalance = c["remaining_balance"] ?? c["balance"] ?? c["remaining"] ?? 0;
      final double balance = rawBalance is num
          ? rawBalance.toDouble()
          : (double.tryParse(rawBalance.toString()) ?? 0.0);

      options.add(LeaveTypeOption(
        id: intId,
        name: name,
        code: c["code"]?.toString() ?? c["leave_type_code"]?.toString(),
        remainingBalance: balance,
      ));
    }

    debugPrint("DEBUG Parsed Dropdown Options: ${options.length} item(s)");
    return options;
  }
}