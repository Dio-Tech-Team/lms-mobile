import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_providers.dart';
<<<<<<< Updated upstream
=======
import '../services/leave_credit_service.dart';
import '../users/login_page.dart';
>>>>>>> Stashed changes

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _creditData;

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

  @override
  Widget build(BuildContext context) {
<<<<<<< Updated upstream
=======
    final user = Provider.of<AuthProvider>(context).user;
    final credits = (_creditData?["credits"] as List<dynamic>? ?? []);

>>>>>>> Stashed changes
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Leave Credits'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
<<<<<<< Updated upstream
      body: const Center(
        child: Text(
          'Welcome!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
=======
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadCredits,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Welcome card
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
                      const SizedBox(height: 24),

                      // Summary boxes row
                      Row(
                        children: [
                          _summaryBox(
                            label: "Leave Types",
                            value: "${credits.length}",
                            icon: Icons.list_alt_rounded,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 12),
                          _summaryBox(
                            label: "Total Days",
                            value: "${credits.fold(0, (sum, c) => sum + (c["total_credits"] as num).toInt())}",
                            icon: Icons.calendar_month_rounded,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 12),
                          _summaryBox(
                            label: "Used Days",
                            value: "${credits.fold(0, (sum, c) => sum + (c["used_credits"] as num).toInt())}",
                            icon: Icons.remove_circle_outline_rounded,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section title
                      const Text(
                        'Leave Balances',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Credit boxes
                      ...credits.map((credit) {
                        final remaining =
                            (credit["remaining_balance"] as num).toDouble();
                        final total =
                            (credit["total_credits"] as num).toDouble();
                        final used =
                            (credit["used_credits"] as num).toDouble();
                        final progress = total > 0
                            ? (used / total).clamp(0.0, 1.0)
                            : 0.0;
                        final isLow = remaining <= 2;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLow
                                  ? Colors.red.shade200
                                  : Colors.transparent,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isLow
                                      ? Colors.red.shade50
                                      : Colors.deepPurple.shade50,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      credit["leave_type"] ?? "",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isLow
                                            ? Colors.red.shade700
                                            : Colors.deepPurple.shade700,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isLow
                                            ? Colors.red.shade100
                                            : Colors.deepPurple.shade100,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        credit["code"] ?? "",
                                        style: TextStyle(
                                          color: isLow
                                              ? Colors.red.shade700
                                              : Colors.deepPurple.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Body
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // 3 stat boxes
                                    Row(
                                      children: [
                                        _creditBox(
                                          label: "Total",
                                          value: "$total",
                                          color: Colors.indigo.shade50,
                                          textColor: Colors.indigo.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        _creditBox(
                                          label: "Used",
                                          value: "$used",
                                          color: Colors.orange.shade50,
                                          textColor: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        _creditBox(
                                          label: "Remaining",
                                          value: "$remaining",
                                          color: isLow
                                              ? Colors.red.shade50
                                              : Colors.green.shade50,
                                          textColor: isLow
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Progress bar
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 8,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              isLow
                                                  ? Colors.red
                                                  : Colors.deepPurple,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}% used',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Low balance warning
                                    if (isLow) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.red.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded,
                                                size: 14,
                                                color: Colors.red.shade600),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Low balance — only $remaining day(s) left',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _creditBox({
    required String label,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: textColor),
            ),
          ],
>>>>>>> Stashed changes
        ),
      ),
    );
  }
}