import 'package:flutter/foundation.dart';

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
  bool operator ==(Object other) => other is LeaveTypeOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static const Map<String, double> _staticLeaveCaps = {
    'Wellness Leave': 5,
    'VAWC Leave': 10,
    'Rehabilitation Leave': 180,
    'Special Leave Benefits for Women': 60,
    'Special Emergency (Calamity) Leave': 5,
    'Adoption Leave': 60,
    'Study Leave': 180,
    'Mandatory/Forced Leave': 5,
    'Maternity Leave': 105,
    'Paternity Leave': 7,
    'Special Privilege Leave': 3,
    'Solo Parent Leave': 7,
  };

  static List<LeaveTypeOption> listFromJson(List<dynamic>? raw) {
    final types = raw ?? [];
    debugPrint("DEBUG LeaveTypeOption received types: $types");

    final options = <LeaveTypeOption>[];

    for (int i = 0; i < types.length; i++) {
      final c = types[i];
      if (c is! Map) continue;

      final rawId =
          c["leave_configuration_id"] ?? c["id"] ?? c["leave_type_id"];
      int? intId;
      if (rawId != null) {
        intId = rawId is int ? rawId : int.tryParse(rawId.toString());
      }
      if (intId == null) {
        debugPrint("DEBUG LeaveTypeOption skipped entry with no usable id: $c");
        continue;
      }

      final name =
          (c["name"] ?? c["leave_type"] ?? c["leave_type_name"] ?? "Leave")
              .toString();

      final rawBalance =
          c["remaining_balance"] ?? c["balance"] ?? c["remaining"] ?? 0;
      double balance = rawBalance is num
          ? rawBalance.toDouble()
          : (double.tryParse(rawBalance.toString()) ?? 0.0);

      if (balance <= 0 && _staticLeaveCaps.containsKey(name)) {
        debugPrint(
          "DEBUG LeaveTypeOption '$name' had balance=$balance from API, "
          "falling back to static cap ${_staticLeaveCaps[name]}",
        );
        balance = _staticLeaveCaps[name]!;
      }

      options.add(
        LeaveTypeOption(
          id: intId,
          name: name,
          code: c["code"]?.toString() ?? c["leave_type_code"]?.toString(),
          remainingBalance: balance,
        ),
      );
    }

    debugPrint("DEBUG Parsed Dropdown Options: ${options.length} item(s)");
    return options;
  }
}