import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../users/login_page.dart';
import '../screentabs/apply_for_leave.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _creditData;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final employeeId = auth.employeeId;
    final token = auth.token;

    if (employeeId == null) {
      setState(() {
        _errorMessage = "No employee record linked to your account.";
        _isLoading = false;
      });
      return;
    }

    final result = await LeaveCreditService.getCredits(employeeId, token!);

    setState(() {
      _isLoading = false;
      if (result["success"]) {
        _creditData = result["data"];
      } else {
        _errorMessage = result["message"];
      }
    });
  }

  Future<void> _goToApplyLeave() async {
    final credits = (_creditData?["credits"] as List<dynamic>? ?? []);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyForLeave(leaveTypes: credits),
      ),
    );

    if (result is Map && result['success'] == true) {
      final leaveConfigId = result['leaveConfigurationId'];
      final daysApplied = result['daysApplied'] as double;

      // Optimistic update so the balance changes instantly.
      setState(() {
        final list = _creditData?["credits"] as List<dynamic>?;
        if (list != null) {
          final idx = list.indexWhere((c) =>
              c["leave_configuration_id"] == leaveConfigId ||
              c["id"] == leaveConfigId);
          if (idx != -1) {
            final currentRemaining =
                double.tryParse(list[idx]["remaining_balance"].toString()) ?? 0;
            final currentUsed =
                double.tryParse(list[idx]["used_credits"].toString()) ?? 0;
            list[idx]["remaining_balance"] = currentRemaining - daysApplied;
            list[idx]["used_credits"] = currentUsed + daysApplied;
          }
        }
      });

      // Reconcile with the server in the background.
      await _loadCredits();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application submitted successfully!')),
        );
      }
    } else if (result == true) {
      // Fallback for older callers that just return `true`.
      await _loadCredits();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application submitted successfully!')),
        );
      }
    }
  }

  double _toDouble(dynamic value) =>
      double.parse(value?.toString() ?? '0');

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final credits = (_creditData?["credits"] as List<dynamic>? ?? []);

    final totalDays = credits.fold(0.0, (sum, c) => sum + _toDouble(c["total_credits"]));
    final usedDays  = credits.fold(0.0, (sum, c) => sum + _toDouble(c["used_credits"]));
    final remaining = totalDays - usedDays;
    final overallProgress = totalDays > 0
        ? (usedDays / totalDays).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Home',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {
                },
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Confirm Logout'),
                    ],
                  ),
                  content: const Text('Do you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
              ),
              const SizedBox(width: 48),
              _bottomNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                index: 1,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _goToApplyLeave,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadCredits,
                  color: Colors.deepPurple,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?["username"] ?? "User"}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_creditData?["employee"] ?? ""} · ${_creditData?["year"] ?? ""}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2D5491)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEAVE BALANCE — ${_creditData?["year"] ?? DateTime.now().year}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Credits',
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          totalDays % 1 == 0
                                              ? '${totalDays.toInt()}'
                                              : '$totalDays',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text('days allocated',
                                            style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Remaining',
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          remaining % 1 == 0
                                              ? '${remaining.toInt()}'
                                              : '$remaining',
                                          style: const TextStyle(
                                            color: Color(0xFF4EEAAA),
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${usedDays % 1 == 0 ? usedDays.toInt() : usedDays} used this year',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Used: ${usedDays % 1 == 0 ? usedDays.toInt() : usedDays} days',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12),
                                ),
                                Text(
                                  '${(overallProgress * 100).toStringAsFixed(0)}% consumed',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: overallProgress,
                                minHeight: 6,
                                backgroundColor:
                                    Colors.white.withOpacity(0.15),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF4EEAAA)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'By Leave Type',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: credits.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, index) {
                          final credit = credits[index];
                          final rem = _toDouble(credit["remaining_balance"]);
                          final tot = _toDouble(credit["total_credits"]);
                          final usd = _toDouble(credit["used_credits"]);
                          final prog = tot > 0
                              ? (usd / tot).clamp(0.0, 1.0)
                              : 0.0;
                          final isLow = rem <= 2;

                          final accentColors = [
                            const Color(0xFF1E3A5F),
                            const Color(0xFF7B5EA7),
                            const Color(0xFFE07B39),
                            const Color(0xFF2AABB8),
                            const Color(0xFF3A8C5C),
                            const Color(0xFFD94F70),
                          ];
                          final accent = isLow
                              ? Colors.red
                              : accentColors[index % accentColors.length];

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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          credit["leave_type"] ?? "",
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
                                    Icon(Icons.calendar_today_rounded,
                                        size: 16, color: accent),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rem % 1 == 0 ? '${rem.toInt()}' : '$rem',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                                Text(
                                  'of ${tot % 1 == 0 ? tot.toInt() : tot} days left',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF8A97A8)),
                                ),
                                const Spacer(),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: prog,
                                    minHeight: 5,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(accent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.deepPurple : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.deepPurple : Colors.grey,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}